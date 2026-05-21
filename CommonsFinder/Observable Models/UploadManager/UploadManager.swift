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

@Observable
class UploadManager {

    private let appDatabase: AppDatabase
    private let accountModel: AccountModel

    @ObservationIgnored private var tasks: [DraftIDType: Task<Void, Error>]

    var queuedSingleUploadables: [DraftIDType: MediaFileUploadable] = [:]
    var queuedMultiUploadables: [DraftIDType: [MediaFileUploadable]] = [:]

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
                        case .none:
                            assertionFailure()
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
        guard !draft.name.isEmpty else {
            throw UploadManagerError.nameMissing
        }

        guard let uniformType = UTType(mimeType: draft.mimeType) else {
            throw UploadManagerError.missingMimetypePreventedFinalFilenameGeneration
        }

        var draft = draft
        draft.finalFilename =
            draft.name
            .appendingFileExtension(conformingTo: uniformType)
            .precomposedStringWithCanonicalMapping
        do {
            return try appDatabase.upsertAndFetch(draft)
        } catch {
            throw .databaseErrorOnFinalFilenameUpdate(error)
        }
    }

    private func updateDraftsWithFinalFilename(multiDraftInfo: MultiDraftInfo) throws(UploadManagerError) -> MultiDraftInfo {
        guard !multiDraftInfo.multiDraft.name.isEmpty else {
            throw UploadManagerError.nameMissing
        }

        let finalFilenames: [MediaFileDraft.ID: String]
        do {
            finalFilenames = try FilenameUtils.generateMultiDraftFinalFilenames(multiDraftInfo: multiDraftInfo)
        } catch {
            throw .failedToGenerateFilenameForMultiUpload
        }

        for draft in multiDraftInfo.drafts {
            var draft = draft
            guard let finalFilename = finalFilenames[draft.id] else {
                throw .failedToGenerateIndividualFilenameForMultiUpload
            }

            do {
                draft.finalFilename = finalFilename
                _ = try appDatabase.upsert(draft)
            } catch {
                throw .databaseErrorOnFinalFilenameUpdate(error)
            }
        }

        let updatedMultiDraftInfo: MultiDraftInfo?
        do {
            updatedMultiDraftInfo = try appDatabase.fetchMultiDraftInfo(id: multiDraftInfo.id)
        } catch {
            throw .databaseErrorOnFinalFilenameUpdate(error)
        }


        guard let updatedMultiDraftInfo else {
            throw .emptyMultiDraftInfoAfterUpdatingFilenames
        }

        return updatedMultiDraftInfo


    }


    func setPublishingState(for draftID: MediaFileDraft.ID, to step: MediaFileDraft.PublishingState?, verificationRequired: Bool = false) throws {
        try appDatabase.updateDraft(id: draftID, withPublishingStep: step, verificationRequired: verificationRequired)
    }

    func setPublishingState(for multiDraftID: MultiDraft.ID, updatedState: MultiDraft.PublishingState?) throws {
        try appDatabase.updateMultiDraft(id: multiDraftID, withPublishingStep: updatedState)
    }

    func setPublishingError(for draftID: MediaFileDraft.ID, error: MediaFileDraft.PublishingError?) throws {
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

    func upload(_ multiDraftInfo: MultiDraftInfo, username: String) {
        var multiDraftInfo = multiDraftInfo

        guard let multiDraftID = multiDraftInfo.id else {
            assertionFailure("We expect the draft to be already stored in the DB before uploading.")
            return
        }

        do {
            multiDraftInfo = try updateDraftsWithFinalFilename(multiDraftInfo: multiDraftInfo)
        } catch {
            logger.error("Failed to set names of multi draft \(error)")
        }

        var uploadables: [MediaFileUploadable] = []

        for draft in multiDraftInfo.drafts {
            do {
                try draft.updateExifLocation()
                let uploadable = try MediaFileUploadable.init(draft, multiDraft: multiDraftInfo.multiDraft, appWikimediaUsername: username)
                uploadables.append(uploadable)

                assert(
                    uploadable.id == draft.id,
                    "We expect the MediaFileDraft in the DB the temporary MediaFileUploadable to have the same ID"
                )
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

        let id = DraftIDType.multiDraft(multiDraftID)
        queuedMultiUploadables[id] = uploadables
        performUpload(id)
    }

    func upload(_ draft: MediaFileDraft, username: String, startStep: API.PublishingStep) {
        // TODO: check auth here instead of failing later, so the upload isn't officially started yet
        // .... try ensureUserIsLoggedIn() // throwing re-auth required

        do {
            try draft.updateExifLocation()
            let finalDraft = try updateDraftWithFinalFilename(draft: draft)
            let id = DraftIDType.singleDraft(finalDraft.id)

            let uploadable = try MediaFileUploadable.init(finalDraft, appWikimediaUsername: username)
            queuedSingleUploadables[id] = uploadable

            assert(
                uploadable.id == finalDraft.id,
                "We expect the MediaFileDraft in the DB the temporary MediaFileUploadable to have the same ID"
            )

            performUpload(id, startStep: startStep)

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

    // FIXME: !!!!! reconsider "startStep" usage

    func performUpload(_ id: DraftIDType, startStep: API.PublishingStep = .uploadData) {
        if #available(iOS 26.0, *) {
            performUploadWithBGTask(id: id, startStep: startStep)
        } else {
            switch id {
            case .singleDraft(let iD):
                performSingleUploadImpl(id: id, startStep: startStep)
            case .multiDraft(let multiDraftID):
                performMultiUploadImpl(id: id)
            }
        }
    }

    @available(iOS 26.0, *)
    private func performUploadWithBGTask(id: DraftIDType, startStep: API.PublishingStep = .uploadData) {
        let bgTaskScheduler = BGTaskScheduler.shared
        let bgTaskIdentifier = "app.CommonsFinder.upload.\(id)"

        if !registeredBGTaskIDs.contains(bgTaskIdentifier) {

            let didRegister = bgTaskScheduler.register(forTaskWithIdentifier: bgTaskIdentifier, using: .main) { [self] bgTask in
                guard let bgTask = bgTask as? BGContinuedProcessingTask else { return }
                bgTask.expirationHandler = {
                    self.tasks[id]?.cancel()
                }

                switch id {
                case .singleDraft(_):
                    performSingleUploadImpl(id: id, startStep: startStep, bgTask: bgTask)
                case .multiDraft(_):
                    performMultiUploadImpl(id: id, bgTask: bgTask)
                }
            }

            guard didRegister else {
                logger.error("Failed to register BG task handler for \(bgTaskIdentifier). Falling back to upload without bgTask.")

                switch id {
                case .singleDraft(_):
                    performSingleUploadImpl(id: id, startStep: startStep)
                case .multiDraft(_):
                    performMultiUploadImpl(id: id)
                }

                assertionFailure()
                return
            }

            registeredBGTaskIDs.insert(bgTaskIdentifier)
        }

        let bgRequest = BGContinuedProcessingTaskRequest(
            identifier: bgTaskIdentifier,
            title: id.isMultiDraft ? "Uploading files" : "Uploading a file",
            subtitle: "About to start...",
        )

        bgRequest.strategy = .queue

        do {
            try bgTaskScheduler.submit(bgRequest)
        } catch {
            logger.error("Failed to submit BG task request for \(bgTaskIdentifier): \(error). Falling back to immediate upload.")
            switch id {
            case .singleDraft(_):
                performSingleUploadImpl(id: id, startStep: startStep)
            case .multiDraft(_):
                performMultiUploadImpl(id: id)
            }
        }
    }

    private func performSingleUploadImpl(id: DraftIDType, startStep: API.PublishingStep = .uploadData, bgTask: BGTask? = nil) {
        guard let uploadable = queuedSingleUploadables[id] else {
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
                queuedSingleUploadables[id] = nil
                logger.debug("Cleanup up queuedUploadables and tasks for \(id) after task finished. bgTask identifier: \(bgTask?.identifier ?? "no BGTask")")
            }

            let request = await Networking.shared.api.publish(file: uploadable, startStep: startStep)

            for await status in request {

                guard !Task.isCancelled else {
                    bgTask?.setTaskCompleted(success: false)
                    return
                }

                switch status {
                case .uploadingFile(let progress):
                    _ = try? setPublishingState(for: uploadable.id, to: .uploading(progress.fractionCompleted))
                    if #available(iOS 26.0, *), let bgTask = bgTask as? BGContinuedProcessingTask {
                        let percentCompleted = Int64(progress.fractionCompleted * 100)
                        bgTask.updateTitle(
                            bgTask.title,
                            subtitle: "\(percentCompleted)% uploaded"
                        )
                        bgTask.progress.completedUnitCount = percentCompleted
                    }
                case .fileKeyObtained(let filekey):
                    _ = try? setPublishingState(for: uploadable.id, to: .uploaded(filekey: filekey))

                case .unstashingFile(let filekey):
                    _ = try? setPublishingState(for: uploadable.id, to: .unstashingFile(filekey: filekey), verificationRequired: true)

                    if #available(iOS 26.0, *),
                        let bgTask = bgTask as? BGContinuedProcessingTask
                    {
                        bgTask.progress.completedUnitCount += 5
                        bgTask.updateTitle(bgTask.title, subtitle: "unstashing the file...")
                    }

                case .creatingWikidataClaims:
                    _ = try? setPublishingState(for: uploadable.id, to: .creatingWikidataClaims, verificationRequired: true)
                    if #available(iOS 26.0, *), let bgTask = bgTask as? BGContinuedProcessingTask {
                        bgTask.progress.completedUnitCount += 5
                        bgTask.updateTitle(bgTask.title, subtitle: "creating metadata...")
                    }

                case .published:
                    _ = try? setPublishingState(for: uploadable.id, to: .published)
                    if #available(iOS 26.0, *),
                        let bgTask = bgTask as? BGContinuedProcessingTask
                    {
                        bgTask.progress.completedUnitCount = bgTask.progress.totalUnitCount
                        bgTask.updateTitle("upload finished", subtitle: "file was published")
                        bgTask.setTaskCompleted(success: true)
                    }

                    cleanupDraftAfterPublished(ids: [uploadable.id])

                case .uploadWarnings(let warnings):
                    if #available(iOS 26.0, *) {
                        bgTask?.setTaskCompleted(success: false)
                    }
                    _ = try? setPublishingError(for: uploadable.id, error: .uploadWarnings(warnings))
                case .urlError(let urlError):
                    if #available(iOS 26.0, *) {
                        bgTask?.setTaskCompleted(success: false)
                    }
                    _ = try? setPublishingError(for: uploadable.id, error: .urlError(urlErrorCode: urlError.errorCode, errorDescription: String(describing: urlError)))
                case .unspecifiedError(let error):
                    _ = try? setPublishingError(for: uploadable.id, error: .error(errorDescription: String(describing: error), recoverySuggestion: nil))
                    if #available(iOS 26.0, *) {
                        bgTask?.setTaskCompleted(success: false)
                    }
                case .fileKeyMissingAfterUpload:
                    _ = try? setPublishingError(
                        for: uploadable.id,
                        error: .error(errorDescription: "The required \"filekey\" was missing after the upload. This indicates bad response data from the server.", recoverySuggestion: ""))
                    if #available(iOS 26.0, *) {
                        bgTask?.setTaskCompleted(success: false)
                    }
                }
            }
        }
    }

    private func performMultiUploadImpl(id: DraftIDType, bgTask: BGTask? = nil) {
        assert(id.isMultiDraft, "We expect a multi draft ID")
        let multiDraftID = id.multiDraftID
        guard let uploadables = queuedMultiUploadables[id] else { return }
        assert(uploadables.count > 1, "We expect to  have multiple uploadables for this id.")

        var publishingState: MultiDraft.PublishingState = .init(
            overallProgress: 0,
            isFinished: false,
            completedCount: 0,
            totalCount: uploadables.count
        )

        var encounteredErrors = false

        if #available(iOS 26.0, *), let bgTask = bgTask as? BGContinuedProcessingTask {
            bgTask.progress.totalUnitCount = 100
            bgTask.progress.completedUnitCount = 0
        }


        tasks[id] = Task<Void, Error> {
            defer {
                tasks[id] = nil
                queuedMultiUploadables[id] = nil
                logger.debug("Cleanup up queuedUploadables and tasks for \(id) after task finished. bgTask identifier: \(bgTask?.identifier ?? "no BGTask")")
            }

            for uploadable in uploadables {
                defer { publishingState.completedCount += 1 }

                try? setPublishingState(for: multiDraftID, updatedState: publishingState)

                let request = await Networking.shared.api.publish(file: uploadable, startStep: .uploadData)

                for await status in request {
                    guard !Task.isCancelled else {
                        bgTask?.setTaskCompleted(success: false)
                        return
                    }

                    if #available(iOS 26.0, *), let bgTask = bgTask as? BGContinuedProcessingTask {
                        bgTask.updateTitle(
                            bgTask.title,
                            subtitle: "File \(publishingState.completedCount + 1)/\(publishingState.totalCount)"
                        )
                    }

                    switch status {
                    case .uploadingFile(let progress):
                        _ = try? setPublishingState(
                            for: uploadable.id,
                            to: .uploading(progress.fractionCompleted)
                        )

                        publishingState.overallProgress =
                            Double(Int(publishingState.completedCount) / publishingState.totalCount) + Double(progress.fractionCompleted / Double(publishingState.totalCount))

                    case .fileKeyObtained(let filekey):
                        _ = try? setPublishingState(for: uploadable.id, to: .uploaded(filekey: filekey))
                    case .unstashingFile(let filekey):
                        _ = try? setPublishingState(for: uploadable.id, to: .unstashingFile(filekey: filekey), verificationRequired: true)
                    case .creatingWikidataClaims:
                        _ = try? setPublishingState(for: uploadable.id, to: .creatingWikidataClaims, verificationRequired: true)
                    case .published:
                        _ = try? setPublishingState(for: uploadable.id, to: .published)
                    case .uploadWarnings(let warnings):
                        encounteredErrors = true
                        _ = try? setPublishingError(for: uploadable.id, error: .uploadWarnings(warnings))
                    case .urlError(let urlError):
                        encounteredErrors = true
                        _ = try? setPublishingError(for: uploadable.id, error: .urlError(urlErrorCode: urlError.errorCode, errorDescription: String(describing: urlError)))
                    case .unspecifiedError(let error):
                        encounteredErrors = true
                        _ = try? setPublishingError(for: uploadable.id, error: .error(errorDescription: String(describing: error), recoverySuggestion: nil))
                    case .fileKeyMissingAfterUpload:
                        encounteredErrors = true
                        _ = try? setPublishingError(
                            for: uploadable.id,
                            error: .error(errorDescription: "The required \"filekey\" was missing after the upload. This indicates bad response data from the server.", recoverySuggestion: ""))
                    }

                    try? setPublishingState(for: multiDraftID, updatedState: publishingState)
                    if #available(iOS 26.0, *), let bgTask = bgTask as? BGContinuedProcessingTask {
                        bgTask.progress.completedUnitCount = Int64(publishingState.overallProgress)
                    }
                }
            }

            publishingState.completedCount = publishingState.totalCount
            publishingState.overallProgress = 100
            publishingState.isFinished = true
            try? setPublishingState(for: multiDraftID, updatedState: publishingState)

            if #available(iOS 26.0, *), let bgTask = bgTask as? BGContinuedProcessingTask {
                bgTask.progress.completedUnitCount = Int64(publishingState.overallProgress)
            }

            if encounteredErrors || publishingState.completedCount != publishingState.totalCount {
                // For multi-drafts we don't clean up the individual drafts if some failed,
                // so the user can review which were succesful or not in the detailed multi-draft list overview.
                bgTask?.setTaskCompleted(success: false)
            } else {
                cleanupDraftAfterPublished(ids: uploadables.map(\.id))
                bgTask?.setTaskCompleted(success: true)
            }

        }
    }


    private func cleanupDraftAfterPublished(ids: [MediaFileDraft.ID]) {
        accountModel.syncUserData()

        Task<Void, Never> {
            // We want to give the user some time to realize that the file has been uploaded, via the green checkmark etc.
            try? await Task.sleep(for: .milliseconds(2000))

            do {
                let deletedFileCount = try appDatabase.deleteDrafts(ids: ids)
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
    case nameMissing
    case finalFilenameMissing
    case failedToGenerateFilenameForMultiUpload
    case failedToGenerateIndividualFilenameForMultiUpload
    case licenseMissing
    case sourceMissing
    case authorMissing
    case missingMimetypePreventedFinalFilenameGeneration
    case databaseErrorOnFinalFilenameUpdate(Error)
    case emptyMultiDraftInfoAfterUpdatingFilenames
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
