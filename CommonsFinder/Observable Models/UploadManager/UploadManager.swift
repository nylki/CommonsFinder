//
//  UploadManager.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 06.11.24.
//

import BackgroundTasks
import Combine
import CommonsAPI
import CoreGraphics
import CoreLocation
import Foundation
import UIKit
import UniformTypeIdentifiers
import os.log

nonisolated enum PublishingError: Equatable, Sendable, CustomStringConvertible, Codable, Hashable {
    case twoFactorCodeRequired
    case emailCodeRequired
    case uploadWarnings([FileUploadResponse.Warning])
    case urlError(urlErrorCode: Int, errorDescription: String)
    case error(errorDescription: String?, recoverySuggestion: String?)
    case appQuitOrCrash

    var description: String {
        switch self {
        case .twoFactorCodeRequired:
            "twoFactorCodeRequired"
        case .emailCodeRequired:
            "emailCodeRequired"
        case .uploadWarnings(let array):
            "uploadWarnings \(array.description)"
        case .error(let errorDescription, let recoverySuggestion):
            "error \(errorDescription ?? ""), \(recoverySuggestion ?? "")"
        case .urlError(let urlErrorCode, let errorDescription):
            "urlError \(urlErrorCode) \(errorDescription)"
        case .appQuitOrCrash:
            "appQuitOrCrash"
        }
    }

    static func == (lhs: PublishingError, rhs: PublishingError) -> Bool {
        lhs.description == rhs.description
    }
}

nonisolated enum PublishingState: Equatable, Sendable, Identifiable, CustomStringConvertible, Codable, Hashable {
    case uploading(_ fractionCompleted: Double)
    case uploaded(filekey: String)
    case unstashingFile(filekey: String)
    case creatingWikidataClaims
    case published

    var uploadProgress: Double? {
        if case .uploading(let fractionCompleted) = self {
            fractionCompleted
        } else {
            nil
        }
    }

    var id: String {
        description
    }

    var description: String {
        switch self {
        case .uploading(let fractionCompleted):
            "uploading \(fractionCompleted)"
        case .uploaded(let filekey):
            "filekey \(filekey)"
        case .creatingWikidataClaims:
            "creatingWikidataClaims"
        case .unstashingFile:
            "unstashingFile"
        case .published:
            "published"
        }
    }

    static func == (lhs: PublishingState, rhs: PublishingState) -> Bool {
        lhs.description == rhs.description
    }
}


@Observable
class UploadManager {

    private let appDatabase: AppDatabase
    private let accountModel: AccountModel

    @ObservationIgnored private var tasks: [MediaFileDraft.ID: Task<Void, Error>]
    /// uploadable per BGTask identifier
    private var queuedUploadables: [MediaFileDraft.ID: MediaFileUploadable] = [:]

    /// remember already registed bgTask identifiers,
    /// to make sure we don't register BGTasks twice during a session (eg. reupload after failed upload),
    /// as this will cause a crash.
    private var registeredBGTaskIDs: Set<String> = .init()
    private var verifyTask: Task<Void, Never>?

    var isVerifyingErrorDrafts: Bool {
        verifyTask != nil
    }

    init(appDatabase: AppDatabase, accountModel: AccountModel) {
        self.appDatabase = appDatabase
        self.accountModel = accountModel
        tasks = .init()
    }

    func runPostLaunchOperations() {
        do {
            try markUnfinishedUploadsAfterAppStartWithError()
        } catch {
            logger.error("Failed to markUnfinishedUploadsAfterAppStartWithError \(error)")
        }

        verifyDraftsWithErrors()
    }

    /// this relates to all drafts whose upload was started, but the app was closed by the user or by a crash.
    /// NOTE: must run before verifyDraftsWithErrors()
    private func markUnfinishedUploadsAfterAppStartWithError() throws {
        let unfinishedDrafts = try appDatabase.fetchDraftsWithPendingUploadButNoError()
        for draft in unfinishedDrafts {
            if draft.publishingState == .published {
                _ = try appDatabase.deleteDrafts(ids: [draft.id])
                continue
            }

            try setPublishingState(for: draft.id, to: draft.publishingState, verificationRequired: true)
            try setPublishingError(for: draft.id, error: .appQuitOrCrash)

        }
    }

    /// When a draft upload is started it can fail for various reasons, some of which can result in an unclear state in the app:
    /// these are: network errors and app crashes/quits, because the backend may have correctly finished network requests, but the app is unaware of the outcame due the the nature of these errors.
    /// This functions asks the backend for the outcome of such drafts and adjusts the `publishingState` if needed.
    func verifyDraftsWithErrors() {
        verifyTask?.cancel()
        verifyTask = Task<Void, Never> {
            defer { verifyTask = nil }
            try? await Task.sleep(for: .seconds(2))
            let drafts: [MediaFileDraft]
            do {
                drafts = try appDatabase.fetchInterruptedDraftsRequiringVerification()
            } catch {
                logger.error("Failed to fetchInterruptedDraftsRequiringVerification \(error)")
                return
            }

            for draft in drafts {
                guard !Task.isCancelled else {
                    return
                }
                guard let publishingState = draft.publishingState else {
                    assertionFailure("We expect drafts returned from fetchInterruptedDraftsRequiringVerification() to always have a publishingState")
                    continue
                }

                do {
                    switch publishingState {
                    case .uploading:
                        logger.debug("No logic for verifying uploads stuck during data upload yet.")
                        continue
                    case .uploaded(let filekey), .unstashingFile(let filekey):
                        // We have to check if it was perhaps already unstashed.
                        let result = try await Networking.shared.api.checkIfFileExists(filename: draft.finalFilename)
                        switch result {
                        case .exists:
                            try setPublishingState(for: draft.id, to: .creatingWikidataClaims, verificationRequired: false)
                        case .doesNotExist:
                            try setPublishingState(for: draft.id, to: .unstashingFile(filekey: filekey), verificationRequired: false)
                        case .invalidFilename:
                            try setPublishingState(for: draft.id, to: .unstashingFile(filekey: filekey), verificationRequired: false)
                        }
                    case .creatingWikidataClaims:
                        // The file is expected to be un-stashed and therefore public, we have to check if the wikidata items have already been created.

                        let fileMetadata = try await Networking.shared.api.fetchFullFileMetadata(FileIdentifierList.titles(["File:\(draft.finalFilename)"])).first

                        if let fileMetadata {
                            if fileMetadata.structuredData.statements.isEmpty {
                                try setPublishingState(for: draft.id, to: .creatingWikidataClaims, verificationRequired: false)
                            } else {
                                try setPublishingState(for: draft.id, to: .published, verificationRequired: false)
                            }
                        } else {
                            try setPublishingState(for: draft.id, to: .creatingWikidataClaims, verificationRequired: false)
                        }

                    case .published:
                        assertionFailure("Draft marked as officially published. This should not have been returned in the interrupted downloads list.")
                        continue
                    }
                } catch {
                    logger.error("Failed to verify interrupted draft upload \(draft.finalFilename) \(draft.publishingState?.description ?? ""). \(error)")
                }
            }
        }

    }

    private func updateDraftWithFinalFilename(draft: MediaFileDraft) throws(UploadManagerError) -> MediaFileDraft {
        guard let uniformType = UTType(mimeType: draft.mimeType) else {
            throw UploadManagerError.missingMimetypePreventedFinalFilenameGeneration
        }

        var draft = draft
        draft.finalFilename = draft.name.appendingFileExtension(conformingTo: uniformType)
        do {
            return try appDatabase.upsertAndFetch(draft)
        } catch {
            throw .databaseErrorOnFinalFilenameUpdate(error)
        }
    }

    @discardableResult
    func setPublishingState(for draftID: MediaFileDraft.ID, to step: PublishingState?, verificationRequired: Bool = false) throws -> MediaFileDraft {
        try appDatabase.updateDraft(id: draftID, withPublishingStep: step, verificationRequired: verificationRequired)
    }

    @discardableResult
    func setPublishingError(for draftID: MediaFileDraft.ID, error: PublishingError?) throws -> MediaFileDraft {
        try appDatabase.updateDraft(id: draftID, withPublishingError: error)
    }
    /// upload  a MediaFileDraft (or resume a previously interrupted upload)
    func upload(_ draft: MediaFileDraft, username: String) {
        switch draft.publishingState {
        case .none, .uploading(_):
            upload(draft, username: username, startStep: .uploadData)
        case .uploaded(let filekey), .unstashingFile(let filekey):
            upload(draft, username: username, startStep: .unstash(filekey: filekey))
        case .creatingWikidataClaims:
            upload(draft, username: username, startStep: .createStructuredData)
        case .published:
            assertionFailure()
            break
        }
    }

    private func upload(_ draft: MediaFileDraft, username: String, startStep: API.PublishingStep) {
        // TODO: check auth here instead of failing later, so the upload isn't officially started yet
        // .... try ensureUserIsLoggedIn() // throwing re-auth required
        do {
            try draft.updateExifLocation()
            let finalDraft = try updateDraftWithFinalFilename(draft: draft)

            let uploadable = try MediaFileUploadable.init(finalDraft, appWikimediaUsername: username)
            queuedUploadables[draft.id] = uploadable

            assert(
                uploadable.id == draft.id,
                "We expect the MediaFileDraft in the DB the temporary MediaFileUploadable to have the same ID"
            )

            performUpload(draft.id, startStep: startStep)

        } catch (.databaseErrorOnFinalFilenameUpdate(let error)) {
            logger.error("Failed to update draft in SQL DB with final filename! \(error)")
        } catch (.missingMimetypePreventedFinalFilenameGeneration) {
            logger.error("Failed to create uploadable because the final filename with file-ending (eg. .jpg) could be be generated because the mimeType is unknown")
        } catch (.fileURLMissing) {
            logger.error("Failed to create uploadable because fileURL field is missing")
        } catch (.onlyDraftsCanBeUploaded) {
            logger.error("Failed to create uploadable because it must be a local draft.")
        } catch (.failedToOverwriteExifLocation(let error)) {
            logger.error("Failed to overwrite exif location \(error)")
        } catch {
            // Swift 6.0 compiler correctly produces warning: “Case will never be executed”
            // retry in XCode 16.3-4
            // see: https://github.com/swiftlang/swift/issues/74555
            logger.error("this is required to silence 'non-exhaustive' error, but generates a 'will never be executed' warning")
        }
    }

    func performUpload(_ id: MediaFileDraft.ID, startStep: API.PublishingStep = .uploadData) {
        if #available(iOS 26.0, *) {
            performUploadWithBGTask(id: id, startStep: startStep)
        } else {
            performUploadImpl(id: id, startStep: startStep)
        }
    }

    @available(iOS 26.0, *)
    private func performUploadWithBGTask(id: MediaFileDraft.ID, startStep: API.PublishingStep = .uploadData) {
        let bgTaskScheduler = BGTaskScheduler.shared
        let bgTaskIdentifier = "app.CommonsFinder.upload.\(id)"

        if !registeredBGTaskIDs.contains(bgTaskIdentifier) {
            let didRegister = bgTaskScheduler.register(forTaskWithIdentifier: bgTaskIdentifier, using: .main) { [self] bgTask in
                guard let bgTask = bgTask as? BGContinuedProcessingTask else { return }
                bgTask.expirationHandler = {
                    self.tasks[id]?.cancel()
                }
                performUploadImpl(id: id, startStep: startStep, bgTask: bgTask)
            }
            guard didRegister else {
                logger.error("Failed to register BG task handler for \(bgTaskIdentifier). Falling back to immediate upload.")
                performUploadImpl(id: id, startStep: startStep)
                assertionFailure()
                return
            }
            registeredBGTaskIDs.insert(bgTaskIdentifier)
        }

        let bgRequest = BGContinuedProcessingTaskRequest(
            identifier: bgTaskIdentifier,
            title: "Uploading a File",
            subtitle: "About to start...",
        )
        bgRequest.strategy = .queue

        do {
            try bgTaskScheduler.submit(bgRequest)
        } catch {
            logger.error("Failed to submit BG task request for \(bgTaskIdentifier): \(error). Falling back to immediate upload.")
            performUploadImpl(id: id, startStep: startStep)
        }
    }

    private func performUploadImpl(id: MediaFileDraft.ID, startStep: API.PublishingStep = .uploadData, bgTask: BGTask? = nil) {
        guard let uploadable = queuedUploadables[id] else {
            assertionFailure()
            return
        }

        // uploadProgressCount is 100 to match the reported data uploaded in percent from the network request
        let uploadProgressCount = 100
        let postUploadProgressCount = 15

        if #available(iOS 26.0, *), let bgTask = bgTask as? BGContinuedProcessingTask {
            bgTask.progress.totalUnitCount = Int64(uploadProgressCount + postUploadProgressCount)
            bgTask.progress.completedUnitCount = 0
        }


        tasks[id] = Task<Void, Error> {
            defer {
                tasks[id] = nil
                queuedUploadables[id] = nil
                logger.debug("Cleanup up queuedUploadables and tasks for \(id) after task finished. bgTask identifier: \(bgTask?.identifier ?? "no BGTask")")
            }

            let csrfToken: String
            do {
                let tokenAuthResult = try await Authentication.fetchCSRFToken()
                switch tokenAuthResult {
                case .twoFactorCodeRequired:
                    // FIXME: actual trigger a re-login when auth failed (eg. due to 2fa, or password change)
                    // and ability to retry/resume
                    try setPublishingError(for: id, error: .twoFactorCodeRequired)
                    bgTask?.setTaskCompleted(success: false)
                    return
                case .emailCodeRequired:
                    // FIXME: actual trigger a re-login when auth failed (eg. due to 2fa, or password change)
                    // and ability to retry/resume
                    try setPublishingError(for: id, error: .emailCodeRequired)
                    bgTask?.setTaskCompleted(success: false)
                    return
                case .tokenReceived(let token):
                    csrfToken = token
                }
            } catch {
                logger.error("failed to fetch CSRF token for upload: \(error)")
                bgTask?.setTaskCompleted(success: false)
                try setPublishingError(for: id, error: .error(errorDescription: error.localizedDescription, recoverySuggestion: "Check if you are logged in to your Wikimedia Account."))
                return
            }

            let request = await Networking.shared.api.publish(file: uploadable, csrfToken: csrfToken, startStep: startStep)

            for await status in request {

                guard !Task.isCancelled else {
                    bgTask?.setTaskCompleted(success: false)
                    return
                }

                switch status {
                case .uploadingFile(let progress):
                    _ = try? setPublishingState(for: id, to: .uploading(progress.fractionCompleted))
                    if #available(iOS 26.0, *), let bgTask = bgTask as? BGContinuedProcessingTask {
                        let percentCompleted = Int64(progress.fractionCompleted * 100)
                        bgTask.updateTitle(
                            bgTask.title,
                            subtitle: "\(percentCompleted)% uploaded"
                        )
                        bgTask.progress.completedUnitCount = percentCompleted
                    }
                case .fileKeyObtained(let filekey):
                    _ = try? setPublishingState(for: id, to: .uploaded(filekey: filekey))

                case .unstashingFile(let filekey):
                    _ = try? setPublishingState(for: id, to: .unstashingFile(filekey: filekey), verificationRequired: true)

                    if #available(iOS 26.0, *),
                        let bgTask = bgTask as? BGContinuedProcessingTask
                    {
                        bgTask.progress.completedUnitCount += 5
                        bgTask.updateTitle(bgTask.title, subtitle: "unstashing the file...")
                    }

                case .creatingWikidataClaims:
                    _ = try? setPublishingState(for: id, to: .creatingWikidataClaims, verificationRequired: true)
                    if #available(iOS 26.0, *), let bgTask = bgTask as? BGContinuedProcessingTask {
                        bgTask.progress.completedUnitCount += 5
                        bgTask.updateTitle(bgTask.title, subtitle: "creating metadata...")
                    }

                case .published:
                    _ = try? setPublishingState(for: id, to: .published)
                    if #available(iOS 26.0, *),
                        let bgTask = bgTask as? BGContinuedProcessingTask
                    {
                        bgTask.progress.completedUnitCount = bgTask.progress.totalUnitCount
                        bgTask.updateTitle("upload finished", subtitle: "file was published")
                        bgTask.setTaskCompleted(success: true)
                    }

                    cleanupDraftAfterPublished(id: id)

                case .uploadWarnings(let warnings):
                    if #available(iOS 26.0, *) {
                        bgTask?.setTaskCompleted(success: false)
                    }
                    _ = try? setPublishingError(for: id, error: .uploadWarnings(warnings))
                case .urlError(let urlError):
                    if #available(iOS 26.0, *) {
                        bgTask?.setTaskCompleted(success: false)
                    }
                    _ = try? setPublishingError(for: id, error: .urlError(urlErrorCode: urlError.errorCode, errorDescription: urlError.localizedDescription))
                case .unspecifiedError(let error):
                    _ = try? setPublishingError(for: id, error: .error(errorDescription: error.localizedDescription, recoverySuggestion: nil))
                    if #available(iOS 26.0, *) {
                        bgTask?.setTaskCompleted(success: false)
                    }
                case .fileKeyMissingAfterUpload:
                    _ = try? setPublishingError(
                        for: id, error: .error(errorDescription: "The required \"filekey\" was missing after the upload. This indicates bad response data from the server.", recoverySuggestion: ""))
                    if #available(iOS 26.0, *) {
                        bgTask?.setTaskCompleted(success: false)
                    }
                }
            }
        }
    }


    private func cleanupDraftAfterPublished(id: MediaFileDraft.ID) {
        accountModel.syncUserData()

        Task<Void, Never> {
            // We want to give the user some time to realize that the file has been uploaded, via the green checkmark etc.
            try? await Task.sleep(for: .milliseconds(2000))

            do {
                let deletedFileCount = try appDatabase.deleteDrafts(ids: [id])
                if deletedFileCount != 0 {
                    logger.info("Deleted \(deletedFileCount) drafts that have been uploaded.")
                }
            } catch {
                logger.error("Failed to remove drafts after upload \(error)")
            }
        }
    }
}

extension MediaFileDraft {
    /// erases existing location on `location=nil`
    fileprivate func updateExifLocation() throws(UploadManagerError) {

        let location: CLLocation?

        switch locationHandling {
        case .exifLocation:
            return
        case .noLocation, .none:
            location = nil
        case .userDefinedLocation(let latitude, let longitude, let precision):
            location = .init(latitude: latitude, longitude: longitude)
        }

        guard let filePath = self.localFileURL() else {
            assertionFailure("We expect the draft to have a local file (url)")
            return
        }

        let data: CFData
        do {
            data = try Data(contentsOf: filePath) as CFData
        } catch {
            throw UploadManagerError.failedToOverwriteExifLocation(error)
        }


        guard let source = CGImageSourceCreateWithData(data, nil),
            let type = CGImageSourceGetType(source),
            let imageRef = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw UploadManagerError.failedToOverwriteExifLocation()
        }

        let options = [kCGImageSourceShouldCache as String: kCFBooleanFalse]
        guard let imgSrc = CGImageSourceCreateWithData(data, options as CFDictionary),
            let rawMetadata = CGImageSourceCopyPropertiesAtIndex(imgSrc, 0, options as CFDictionary)
        else {
            throw UploadManagerError.failedToOverwriteExifLocation()
        }

        let metadata = NSMutableDictionary(dictionary: rawMetadata)

        if let location {
            metadata[kCGImagePropertyGPSDictionary] = location.gpsDictionary
        } else {
            metadata.removeObject(forKey: kCGImagePropertyGPSDictionary)
        }

        guard let destination = CGImageDestinationCreateWithURL(filePath as CFURL, type, 1, nil) else {
            throw UploadManagerError.failedToOverwriteExifLocation()
        }

        CGImageDestinationAddImage(destination, imageRef, metadata as CFDictionary)
        let success = CGImageDestinationFinalize(destination)
        if !success {
            throw UploadManagerError.failedToOverwriteExifLocation()
        }
    }
}


enum UploadManagerError: Error {
    case onlyDraftsCanBeUploaded(id: String)
    case fileURLMissing(id: String)
    case finalFilenameMissing
    case licenseMissing
    case sourceMissing
    case authorMissing
    case missingMimetypePreventedFinalFilenameGeneration
    case databaseErrorOnFinalFilenameUpdate(Error)
    case failedToReadFileData
    case failedToOverwriteExifLocation(Error? = nil)
}

//extension API.PublishingStep {
//    init(publishingState: PublishingStepState) {
//        switch publishingState {
//        case .uploading(_):
//            self = .uploadData
//        case .uploaded(let filekey):
//            self = .unstash(filekey: filekey)
//        case .creatingWikidataClaims:
//            self =  .createStructuredData
//        case .unstashingFile(let filekey):
//            self =  .unstash(filekey: filekey)
//        case .published:
//            break
//        }
//    }
//}
