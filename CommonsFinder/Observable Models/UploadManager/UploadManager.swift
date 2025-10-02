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

    @ObservationIgnored private var tasks: [MediaFile.ID: Task<Void, Error>]

    // UploadStatus should be something scoped to the App, not the API package
    var uploadStatus: [MediaFile.ID: UploadManagerStatus]
    var didFinishUpload: PassthroughSubject<String, Never>

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
            performUpload(uploadable)

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

    func performUpload(_ uploadable: MediaFileUploadable) {

        let bgTaskIdentifier = "app.CommonsFinder.upload"
        let bgRequest = BGContinuedProcessingTaskRequest(
            identifier: bgTaskIdentifier,
            title: "A file upload",
            subtitle: "About to start...",
        )
        bgRequest.strategy = .queue

        let bgTaskScheduler = BGTaskScheduler.shared

        bgTaskScheduler.register(forTaskWithIdentifier: bgTaskIdentifier, using: .main) { [self] task in
            guard let task = task as? BGContinuedProcessingTask else { return }

            task.expirationHandler = {
                self.tasks[uploadable.id]?.cancel()
            }

            tasks[uploadable.id] = Task<Void, Error> {
                let csrfToken: String
                do {
                    let tokenAuthResult = try await Authentication.fetchCSRFToken()
                    switch tokenAuthResult {
                    case .twoFactorCodeRequired:
                        // FIXME: actual trigger a re-login when auth failed (eg. due to 2fa, or password change)
                        // and ability to retry/resume
                        uploadStatus[uploadable.id] = .twoFactorCodeRequired
                        task.setTaskCompleted(success: false)
                        return
                    case .emailCodeRequired:
                        // FIXME: actual trigger a re-login when auth failed (eg. due to 2fa, or password change)
                        // and ability to retry/resume
                        uploadStatus[uploadable.id] = .emailCodeRequired
                        task.setTaskCompleted(success: false)
                        return
                    case .tokenReceived(let token):
                        csrfToken = token
                    }
                } catch {
                    logger.error("failed to fetch CSRF token for upload: \(error)")
                    task.setTaskCompleted(success: false)
                    uploadStatus[uploadable.id] = .unspecifiedError(error)
                    return
                }

                let request = await API.shared.publish(file: uploadable, csrfToken: csrfToken)

                for await status in request {
                    switch status {
                    case .uploadingFile(let progress):
                        uploadStatus[uploadable.id] = .uploading(progress.fractionCompleted)
                        task.progress.completedUnitCount = progress.completedUnitCount
                        task.updateTitle(bgRequest.title, subtitle: "\(UInt(progress.fractionCompleted * 100))% uploaded")
                    case .creatingWikidataClaims:
                        uploadStatus[uploadable.id] = .creatingWikidataClaims
                        task.updateTitle(bgRequest.title, subtitle: "creating metadata...")
                    case .unstashingFile:
                        uploadStatus[uploadable.id] = .unstashingFile
                        task.updateTitle(bgRequest.title, subtitle: "unstashing the file...")
                    case .published:
                        uploadStatus[uploadable.id] = .published
                        task.updateTitle("upload succesfull", subtitle: "file was published")
                        task.setTaskCompleted(success: true)
                        didFinishUpload.send(uploadable.filename)
                    case .uploadWarnings(let warnings):
                        task.setTaskCompleted(success: false)
                        uploadStatus[uploadable.id] = .uploadWarnings(warnings)
                    case .unspecifiedError(let error):
                        task.setTaskCompleted(success: false)
                        uploadStatus[uploadable.id] = .unspecifiedError(error)
                    }

                    try Task.checkCancellation()
                }
            }
        }

        do {
            try bgTaskScheduler.submit(bgRequest)
        } catch {
            print("Failed to submit request: \(error)")
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
