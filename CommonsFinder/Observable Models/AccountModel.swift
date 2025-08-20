//
//  Authentication.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.11.24.
//

import CommonsAPI
import Foundation
import os.log

struct User: Sendable, Codable, Hashable, Equatable {
    //    let id: String
    let username: String
    var userPage: URL? {
        URL(string: "https://commons.wikimedia.org/wiki/User:\(username)")
    }

    init(username: String) {
        let capitalizedUsername = username.capitalizingFirstLetter()
        logger.info("Saving username as capitalized version \(username) -> \(capitalizedUsername)")
        // see: https://en.wikipedia.org/wiki/Wikipedia:Username_policy

        self.username = capitalizedUsername
    }
}

enum LoginSuccess {
    case loggedIn(User)
    case twoFactorCodeRequired
    case emailCodeRequired
}

// UserManager is designed to be lean and does not hold any data unrelated to authentication
// and basic profile data (username, profile image, preferences?)

// It also explicity **should not store information about uploads**. That should be stored inside the DB
// and  dynamically queried in views via GRDB @Query so as little memory.


@Observable @MainActor
final class AccountModel {
    private(set) var activeUser: User?

    @ObservationIgnored
    private var postLoginTask: Task<Void, Never>?
    private var recurringSyncTask: Task<Void, Never>?
    private let appDatabase: AppDatabase

    init(appDatabase: AppDatabase) {
        self.appDatabase = appDatabase
        do {
            if let activeUsername = try Authentication.retrieveActiveUsername() {
                let user = User(username: activeUsername)
                self.activeUser = user
            }
        } catch {
            logger.error("Auth error (TODO: really an error or just not yet saved?): \(error)")
        }
    }

    /// This init is intended for SwiftUI-Preview and test views only
    convenience init(appDatabase: AppDatabase, withTestUser testUser: User) {
        self.init(appDatabase: appDatabase)
        self.activeUser = testUser
    }

    func logout() throws {
        postLoginTask?.cancel()
        activeUser = nil
        let deletedCount = try appDatabase.deleteAllImageModels()
        // FIXME: also delete categories and all interactions
        logger.info("Deleted \(deletedCount) items on-logout")
        try Authentication.clearKeychain()
    }


    @discardableResult
    func login(username: String, password: String, oneTimeCode: OneTimeCode?) async throws(Authentication.AuthError) -> LoginSuccess {
        guard activeUser == nil else {
            throw .existingUserLogin
        }

        // see uppercasing: https://en.wikipedia.org/wiki/Wikipedia:Username_policy
        let username = username.capitalizingFirstLetter()
        let result = try await Authentication.login(username: username, password: password, oneTimeCode: oneTimeCode)

        switch result {
        case .twoFactorCodeRequired: return .twoFactorCodeRequired
        case .emailCodeRequired: return .emailCodeRequired
        case .authenticationComplete:
            let user = User(username: username)
            activeUser = user
            schedulePostLoginTasks(forUser: user)
            return .loggedIn(user)
        }
    }

    func ensureUserIsAuthenticated() {

    }

    func createAccount(username: String, password: String, email: String, captchaWord: String, captchaID: String, token: String) async throws(Authentication.AuthError) -> User {
        // see uppercasing: https://en.wikipedia.org/wiki/Wikipedia:Username_policy
        let username = username.capitalizingFirstLetter()

        try await Authentication.createAccount(
            username: username,
            password: password,
            email: email,
            captchaWord: captchaWord,
            captchaID: captchaID,
            token: token
        )

        let user = User(username: username)
        activeUser = user
        schedulePostLoginTasks(forUser: user)

        return user
    }

    private func schedulePostLoginTasks(forUser user: User) {
        postLoginTask = Task<Void, Never> {
            logger.info("schedulePostLoginTasks...")
            defer { postLoginTask = nil }
            do {
                try await withThrowingDiscardingTaskGroup { taskGroup in
                    taskGroup.addTask(operation: fetchMostRecentUploads)
                    taskGroup.addTask(operation: fetchUserProfile)
                }
            } catch {
                // FIXME: retry on error and somehow persist the information for re-launches
                // eg.: lastSync: Date?
                // perhaps even per-task?
                logger.error("Failed to perform post login tasks! Retry these! \(error)")
            }

        }

    }

    func fetchUserProfile() async throws {

    }

    func syncUserData() {
        guard postLoginTask == nil, recurringSyncTask == nil else {
            logger.notice("Tried to sync user data, but a sync task is already running.")
            return
        }

        recurringSyncTask = Task<Void, Never> {
            defer { recurringSyncTask = nil }
            do {
                try await self.fetchMostRecentUploads()
            } catch {
                logger.error("sync task failed: \(error)")
            }
        }
    }

    func removeUploadedDrafts(filenames: [String]) {
        do {
            let deletedFileCount = try appDatabase.deleteDrafts(withFinalFilenames: filenames)
            if deletedFileCount != 0 {
                logger.info("Deleted \(deletedFileCount) drafts that have been uploaded.")
            }
        } catch {
            logger.error("Failed to remove drafts after upload \(error)")
        }

    }

    /// Looks for Drafts that are already known as MediaFile (thus have been uploaded) and removes them
    func cleanupOldDrafts() throws {
        guard let username = activeUser?.username else {
            logger.warning("Tried to removeUploadedDrafts, but no user logged in.")
            return
        }
        let draftFinalFilenames =
            try appDatabase
            .fetchAllDrafts()
            .map(\.finalFilename)

        let draftsToCleanup =
            try appDatabase
            .fetchAllFiles(byUsername: username, withNames: draftFinalFilenames)
            .map(\.name)

        let deletedFileCount = try appDatabase.deleteDrafts(withFinalFilenames: draftsToCleanup)
        if deletedFileCount != 0 {
            logger.info("Deleted \(deletedFileCount) drafts that have been uploaded.")
        }
    }

    /// Start paginating from most recent entry in DB up to Date.now
    private func fetchMostRecentUploads() async throws {
        guard let username = activeUser?.username else {
            logger.warning("Tried to fetchMostRecentUploads, but no user logged in.")
            return
        }

        let mostRecentUploadDate: Date? = try appDatabase.fetchMostRecentUploadDate(byUsername: username)

        if let mostRecentUploadDate {
            // Add 1s to the date, otherwise the newst upload will be fetched again.
            // 1s is the smallest granularity for this API, everything smaller doesn't work.
            // This should (hopefully) not miss any uploads that happen in between.
            let startDate = mostRecentUploadDate.addingTimeInterval(1)
            // Fully paginate from last know most recent uploaded file to newest
            logger.info("fetchMostRecentUploads: last upload on \(mostRecentUploadDate).")
            var continueString: String? = ""
            var totalFetchCount = 0
            while continueString != nil {
                try Task.checkCancellation()
                let response = try await API.shared.listUserImages(
                    of: username,
                    limit: .max,
                    start: startDate,
                    end: nil,
                    direction: .newer,
                    continueString: continueString
                )

                guard !response.files.isEmpty else {
                    break
                }

                let titles = response.files.map(\.title)
                continueString = response.continueString


                let mediaFiles = try await API.shared
                    .fetchFullFileMetadata(fileNames: titles)
                    .map(MediaFile.init)

                _ = try appDatabase.upsert(mediaFiles)
                totalFetchCount += mediaFiles.count
                if let debugMostRecentDate = mediaFiles.sorted(by: \.uploadDate, .orderedDescending).first?.uploadDate {
                    logger.info("fetchMostRecentUploads: fetched + upserted so far \(totalFetchCount), most recent one: \(debugMostRecentDate).")
                } else {
                    logger.info("fetchMostRecentUploads: No files, finished?")
                }
            }

            logger.info("fetchMostRecentUploads: finished. total fetch count: \(totalFetchCount)")
        } else {
            // DB seems to be empty, do an initial fetch of a limited amount of user uploads
            let limit = 50
            logger.info("fetchMostRecentUploads: No files synced yet, fetch initial batch of \(limit) recent user uploads")

            let response = try await API.shared.listUserImages(
                of: username,
                limit: .count(limit),
                start: .now,
                end: nil,
                direction: .older,
                continueString: nil
            )

            let titles = response.files.map(\.title)
            guard titles.isEmpty == false else {
                return
            }

            let mediaFiles = try await API.shared
                .fetchFullFileMetadata(fileNames: titles)
                .map(MediaFile.init)

            _ = try appDatabase.upsert(mediaFiles)
        }
    }
}
