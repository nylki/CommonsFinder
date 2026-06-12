//
//  Authentication.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.11.24.
//

import Algorithms
import CommonsAPI
import Foundation
import OAuthenticator
import SwiftSecurity
import os.log

nonisolated struct User: Sendable, Codable, Hashable, Equatable {
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

nonisolated extension User {
    init(_ profileInfo: CommonsAPI.ProfileInfo) {
        self.username = profileInfo.username
    }
}

enum LoginSuccess {
    case loggedIn(User)
    case twoFactorCodeRequired
    case emailCodeRequired
}

// AccountModel is designed to be lean. It only holds basic profile data (username, profile image, preferences?)
// It also explicity **should not store information about uploads**. That should be stored inside the DB
// and  dynamically queried in views via GRDB @Query so as little memory.

@Observable
final class AccountModel {
    private(set) var activeUser: User?

    @ObservationIgnored
    private var postLoginTask: Task<Void, Never>?
    private var recurringSyncTask: Task<Void, Never>?
    private let appDatabase: AppDatabase

    init(appDatabase: AppDatabase) {
        self.appDatabase = appDatabase

        do {
            if let activeUsername = try Keychain.default.retrieveActiveUsername() {
                self.activeUser = User(username: activeUsername)
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

    func logout() async throws {
        postLoginTask?.cancel()
        postLoginTask = nil
        recurringSyncTask?.cancel()
        recurringSyncTask = nil
        activeUser = nil
        try appDatabase.deleteLogoutRelatedItems()
        try await Networking.shared.logoutAndClearKeychain()
    }


    func addAccount() {
        guard activeUser == nil else { return }
        Task {
            do {
                try await Networking.shared.authenticate()
                let profileInfo = try await Networking.shared.api.fetchProfileInfo()
                let user = User(profileInfo)
                activeUser = user
                try Keychain.default.storeActiveUsername(user.username)
                schedulePostLoginTasks()
            } catch {
                logger.error("error adding account \(error)")
            }
        }
    }

    private func schedulePostLoginTasks() {
        postLoginTask = Task<Void, Never> {
            logger.info("schedulePostLoginTasks...")
            defer { postLoginTask = nil }
            do {
                try await withThrowingDiscardingTaskGroup { taskGroup in
                    taskGroup.addTask {
                        try await self.fetchMostRecentUploads()
                    }
                }
                UserDefaults.standard.set(Date.now, forKey: "lastSyncDate")
            } catch {
                // FIXME: retry on error and somehow persist the information for re-launches
                // eg.: lastSync: Date?
                // perhaps even per-task?
                logger.error("Failed to perform post login tasks! Retry these! \(error)")
            }

        }

    }

    func syncUserData() {
        guard postLoginTask == nil, recurringSyncTask == nil else {
            logger.notice("Tried to sync user data, but a sync task is already running.")
            return
        }

        var lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date

        if let date = lastSyncDate {
            if Date.now.timeIntervalSince(date) < 1 {
                logger.info("Prevent syncing user data, as it was performed less than a second ago.")
                return
            }
            // if we have a last sync date, go 1s into the past, just in case
            lastSyncDate = date.addingTimeInterval(-1)
        }

        recurringSyncTask = Task<Void, Never> {
            defer { recurringSyncTask = nil }
            do {
                try await fetchMostRecentUploads(end: lastSyncDate)
                UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
            } catch {
                logger.error("sync task failed: \(error)")
            }
        }
    }
    /// Looks for Drafts that are already known as MediaFile (thus have been uploaded) and removes them
    func cleanupOldDrafts() throws {
        guard let username = activeUser?.username else {
            logger.warning("Tried to removeUploadedDrafts, but no user logged in.")
            return
        }
        var existingDraftIDsPerFilename: [String: MediaFileDraft.ID] = [:]
        let currentDrafts = try appDatabase.fetchAllDrafts()

        for draft in currentDrafts {
            existingDraftIDsPerFilename[draft.finalFilename] = draft.id
        }

        let filenamesToRemove =
            try appDatabase
            .fetchAllFiles(byUsername: username, withNames: currentDrafts.map(\.name))
            .map(\.name)
            .filter { !$0.isEmpty }

        let draftIDsToRemove = filenamesToRemove.compactMap { filename in
            existingDraftIDsPerFilename[filename]
        }

        guard !draftIDsToRemove.isEmpty else { return }

        let deletedFileCount = try appDatabase.deleteDrafts(ids: draftIDsToRemove)
        if deletedFileCount != 0 {
            logger.info("Deleted \(deletedFileCount) drafts that have been uploaded.")
        }
    }

    /// fetches the most recent 50 user images and upserts them into DB
    private func fetchMostRecentUploads(end: Date? = nil) async throws {
        guard let username = activeUser?.username else {
            logger.warning("Tried to fetchMostRecentUploads, but no user logged in.")
            return
        }

        let response = try await Networking.shared.api.listUserImages(
            of: username,
            limit: .count(50),
            start: nil,
            end: end,
            direction: .older,
            continueString: nil
        )

        let titles = response.titles

        guard !titles.isEmpty else { return }

        let apiFetchLimit = 50
        let titlesChunked = titles.chunks(ofCount: apiFetchLimit)

        for titleChunk in titlesChunked {
            let mediaFiles = try await Networking.shared.api
                .fetchFullFileMetadata(.titles(Array(titleChunk)))
                .map(MediaFile.init)

            _ = try appDatabase.upsert(mediaFiles)
        }


    }
}
