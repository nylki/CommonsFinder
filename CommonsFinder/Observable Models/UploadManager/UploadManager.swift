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

enum UploadManagerStatus: Equatable, Sendable, Identifiable, CustomStringConvertible {
    case uploading(_ fractionCompleted: Double)
    case twoFactorCodeRequired
    case emailCodeRequired
    case creatingWikidataClaims
    case unstashingFile
    case published
    case uploadWarnings([FileUploadResponse.Warning])
    case unspecifiedError(Error)
    case error(LocalizedError)

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
        case .twoFactorCodeRequired:
            "twoFactorCodeRequired"
        case .emailCodeRequired:
            "emailCodeRequired"
        case .creatingWikidataClaims:
            "creatingWikidataClaims"
        case .unstashingFile:
            "unstashingFile"
        case .published:
            "published"
        case .uploadWarnings(let array):
            "uploadWarnings \(array.description)"
        case .unspecifiedError(let error):
            "unspecifiedError \(error.localizedDescription)"
        case .error(let localizedError):
            "error \(localizedError)"
        }
    }

    static func == (lhs: UploadManagerStatus, rhs: UploadManagerStatus) -> Bool {
        lhs.description == rhs.description
    }
}


@Observable
class UploadManager {

    private let appDatabase: AppDatabase

    @ObservationIgnored private var tasks: [MediaFileDraft.ID: Task<Void, Error>]
    /// uploadable per BGTask identifier
    private var queuedUploadables: [MediaFileDraft.ID: MediaFileUploadable] = [:]

    /// remember already registed bgTask identifiers,
    /// to make sure we don't register BGTasks twice during a session (eg. reupload after failed upload),
    /// as this will cause a crash.
    private var registeredBGTaskIDs: Set<String> = .init()

    // UploadStatus should be something scoped to the App, not the API package
    var uploadStatus: [MediaFileDraft.ID: UploadManagerStatus]
    var didFinishUpload: PassthroughSubject<MediaFileDraft.ID, Never>


    init(appDatabase: AppDatabase) {
        self.appDatabase = appDatabase
        tasks = .init()
        uploadStatus = .init()
        didFinishUpload = .init()

    }

    private func updateDraftWithFinalFilename(draft: MediaFileDraft) throws(UploadManagerError) -> MediaFileDraft {
        guard let mimeType = draft.mimeType,
            let uniformType = UTType(mimeType: mimeType)
        else {
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


    func upload(_ draft: MediaFileDraft, username: String) {
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

            performUpload(draft.id)

        } catch (.databaseErrorOnFinalFilenameUpdate(let error)) {
            print("Failed to update draft in SQL DB with final filename! \(error)")
        } catch (.missingMimetypePreventedFinalFilenameGeneration) {
            print("Failed to create uploadable because the final filename with file-ending (eg. .jpg) could be be generated because the mimeType is unknown")
        } catch (.fileURLMissing) {
            print("Failed to create uploadable because fileURL field is missing")
        } catch (.onlyDraftsCanBeUploaded) {
            print("Failed to create uploadable because it must be a local draft.")
        } catch (.failedToOverwriteExifLocation(let error)) {
            print("Failed to overwrite exif location.")
        } catch {
            // Swift 6.0 compiler correctly produces warning: “Case will never be executed”
            // retry in XCode 16.3-4
            // see: https://github.com/swiftlang/swift/issues/74555
            print("this is required to silence 'non-exhaustive' error, but generates a 'will never be executed' warning")
        }
    }

    func performUpload(_ id: MediaFileDraft.ID) {
        if #available(iOS 26.0, *) {
            performUploadWithBGTask(id: id)
        } else {
            performUploadImpl(id: id)
        }
    }

    @available(iOS 26.0, *)
    private func performUploadWithBGTask(id: MediaFileDraft.ID) {
        let bgTaskScheduler = BGTaskScheduler.shared
        let bgTaskIdentifier = "app.CommonsFinder.upload.\(id)"

        if !registeredBGTaskIDs.contains(bgTaskIdentifier) {
            bgTaskScheduler.register(forTaskWithIdentifier: bgTaskIdentifier, using: .main) { [self] bgTask in
                guard let bgTask = bgTask as? BGContinuedProcessingTask else { return }
                bgTask.expirationHandler = {
                    self.tasks[id]?.cancel()
                }
                performUploadImpl(id: id, bgTask: bgTask)
            }
        }

        let bgRequest = BGContinuedProcessingTaskRequest(
            identifier: bgTaskIdentifier,
            title: "A file upload",
            subtitle: "About to start...",
        )
        bgRequest.strategy = .queue

        do {
            try bgTaskScheduler.submit(bgRequest)
        } catch {
            print("Failed to submit request: \(error)")
        }
    }

    private func performUploadImpl(id: MediaFileDraft.ID, bgTask: BGTask? = nil) {
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
                    uploadStatus[id] = .twoFactorCodeRequired
                    bgTask?.setTaskCompleted(success: false)
                    return
                case .emailCodeRequired:
                    // FIXME: actual trigger a re-login when auth failed (eg. due to 2fa, or password change)
                    // and ability to retry/resume
                    uploadStatus[id] = .emailCodeRequired
                    bgTask?.setTaskCompleted(success: false)
                    return
                case .tokenReceived(let token):
                    csrfToken = token
                }
            } catch {
                logger.error("failed to fetch CSRF token for upload: \(error)")
                bgTask?.setTaskCompleted(success: false)
                uploadStatus[id] = .unspecifiedError(error)
                return
            }

            let request = await API.shared.publish(file: uploadable, csrfToken: csrfToken)

            for await status in request {

                guard !Task.isCancelled else {
                    bgTask?.setTaskCompleted(success: false)
                    uploadStatus[id] = nil
                    return
                }

                switch status {
                case .uploadingFile(let progress):
                    uploadStatus[id] = .uploading(progress.fractionCompleted)
                    if #available(iOS 26.0, *), let bgTask = bgTask as? BGContinuedProcessingTask {
                        let percentCompleted = Int64(progress.fractionCompleted * 100)
                        bgTask.updateTitle(
                            bgTask.title,
                            subtitle: "\(percentCompleted)% uploaded"
                        )
                        bgTask.progress.completedUnitCount = percentCompleted
                    }

                case .creatingWikidataClaims:
                    uploadStatus[id] = .creatingWikidataClaims

                    if #available(iOS 26.0, *), let bgTask = bgTask as? BGContinuedProcessingTask {
                        bgTask.progress.completedUnitCount += 5
                        bgTask.updateTitle(bgTask.title, subtitle: "creating metadata...")
                    }

                case .unstashingFile:
                    uploadStatus[id] = .unstashingFile
                    if #available(iOS 26.0, *),
                        let bgTask = bgTask as? BGContinuedProcessingTask
                    {
                        bgTask.progress.completedUnitCount += 5
                        bgTask.updateTitle(bgTask.title, subtitle: "unstashing the file...")
                    }

                case .published:
                    uploadStatus[id] = .published
                    if #available(iOS 26.0, *),
                        let bgTask = bgTask as? BGContinuedProcessingTask
                    {
                        bgTask.progress.completedUnitCount = bgTask.progress.totalUnitCount
                        bgTask.updateTitle("upload finished", subtitle: "file was published")
                        bgTask.setTaskCompleted(success: true)
                    }

                    didFinishUpload.send(id)

                case .uploadWarnings(let warnings):
                    if #available(iOS 26.0, *) {
                        bgTask?.setTaskCompleted(success: false)
                    }

                    uploadStatus[id] = .uploadWarnings(warnings)

                case .unspecifiedError(let error):
                    if #available(iOS 26.0, *) {
                        bgTask?.setTaskCompleted(success: false)
                    }

                    uploadStatus[id] = .unspecifiedError(error)
                }
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
