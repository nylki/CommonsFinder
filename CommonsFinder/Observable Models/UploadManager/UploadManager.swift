//
//  UploadManager.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 06.11.24.
//

import Combine
import CommonsAPI
import CoreGraphics
import CoreLocation
import Foundation
import UIKit
import UniformTypeIdentifiers
import os.log

enum UploadManagerStatus: Equatable {
    case uploading(_ fractionCompleted: Double)
    case twoFactorCodeRequired
    case emailCodeRequired
    case creatingWikidataClaims
    case unstashingFile
    case published
    case uploadWarnings([FileUploadResponse.Warning])
    case unspecifiedError(String)
    case authenticationError(Error?)
    case error(LocalizedError)

    var uploadProgress: Double? {
        if case let .uploading(fractionCompleted) = self {
            fractionCompleted
        } else {
            nil
        }
    }

    static func == (lhs: UploadManagerStatus, rhs: UploadManagerStatus) -> Bool {
        return switch lhs {
        case .twoFactorCodeRequired, .emailCodeRequired, .authenticationError, .creatingWikidataClaims, .unstashingFile, .published:
            lhs == rhs
        case .uploading(let lhsCompleted):
            if case .uploading(let rhsCompleted) = rhs {
                lhsCompleted == rhsCompleted
            } else {
                false
            }
        case .uploadWarnings(let lhsArray):
            if case .uploadWarnings(let rhsArray) = rhs {
                lhsArray == rhsArray
            } else {
                false
            }
        case .error(let lhsError):
            if case .error(let rhsError) = rhs {
                lhsError.errorDescription == rhsError.errorDescription
            } else {
                false
            }
        case .unspecifiedError(let lhsError):
            if case .unspecifiedError(let rhsError) = rhs {
                lhsError == rhsError
            } else {
                false
            }
        }
    }
}


@Observable @MainActor
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
            tasks[finalDraft.id] = Task<Void, Error> {
                await performUpload(uploadable)
            }

        } catch (.databaseErrorOnFinalFilenameUpdate(let error)) {
            logger.fault("Failed to update draft in SQL DB with final filename! \(error)")
        } catch (.missingMimetypePreventedFinalFilenameGeneration) {
            logger.warning("Failed to create uploadable because the final filename with file-ending (eg. .jpg) could be be generated because the mimeType is unknown \(nil)")
        } catch (.fileURLMissing) {
            logger.warning("Failed to create uploadable because fileURL field is missing \(nil)")
        } catch (.onlyDraftsCanBeUploaded) {
            logger.warning("Failed to create uploadable because it must be a local draft. \(nil)")
        } catch (.failedToOverwriteExifLocation(let error)) {
            logger.warning("Failed to overwrite exif location. \(error)")
        } catch {
            // Swift 6.0 compiler correctly produces warning: “Case will never be executed”
            // retry in XCode 16.3-4
            // see: https://github.com/swiftlang/swift/issues/74555
            print("this is required to silence 'non-exhaustive' error, but generates a 'will never be executed' warning")
        }
    }

    func performUpload(_ uploadable: MediaFileUploadable) async {
        let csrfToken: String

        do {
            let tokenAuthResult = try await Authentication.fetchCSRFToken()
            switch tokenAuthResult {
            case .twoFactorCodeRequired:
                // FIXME: actual trigger a re-login when auth failed (eg. due to 2fa, or password change)
                // and ability to retry/resume
                uploadStatus[uploadable.id] = .twoFactorCodeRequired
                return
            case .emailCodeRequired:
                // FIXME: actual trigger a re-login when auth failed (eg. due to 2fa, or password change)
                // and ability to retry/resume
                uploadStatus[uploadable.id] = .emailCodeRequired
                return
            case .tokenReceived(let token):
                csrfToken = token
            }
        } catch {
            logger.error("failed to fetch CSRF token for upload: \(error)")
            uploadStatus[uploadable.id] = .authenticationError(error)
            return
        }

        let request = await API.shared.publish(file: uploadable, csrfToken: csrfToken)

        for await status in request {
            switch status {
            case .uploadingFile(let progress):
                uploadStatus[uploadable.id] = .uploading(progress.fractionCompleted)
            case .creatingWikidataClaims:
                uploadStatus[uploadable.id] = .creatingWikidataClaims
            case .unstashingFile:
                uploadStatus[uploadable.id] = .unstashingFile
            case .published:
                uploadStatus[uploadable.id] = .published
                didFinishUpload.send(uploadable.filename)
            case .uploadWarnings(let warnings):
                uploadStatus[uploadable.id] = .uploadWarnings(warnings)
            case .unspecifiedError(let errorMessage):
                uploadStatus[uploadable.id] = .unspecifiedError(errorMessage)
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
        case .noLocation:
            location = nil
        case .userDefinedLocation(let latitude, let longitude):
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
    case missingMimetypePreventedFinalFilenameGeneration
    case databaseErrorOnFinalFilenameUpdate(Error)
    case failedToReadFileData
    case failedToOverwriteExifLocation(Error? = nil)
}
