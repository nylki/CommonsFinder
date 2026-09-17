//
//  FileImportModel.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 13.10.24.
//

import AsyncAlgorithms
import GRDB
import OrderedCollections
import PhotosUI
import SwiftUI
import os.log

enum DraftError: Error {
    case missingFileInformation
    case filenameExistsAlready(name: String)
}

enum FileImportError: Error {
    case failedToGetLocalFileURL
    case fileAccessDenied(URL)
    case failedToConvertPhotoItemToData
    case failedToConvertUIImageToData
    case failedToWriteImageWithMetadataToFile
    case unrecognizedFileType(String)
    case unsupportedContentType([UTType])
}

@Observable class FileImportModel: Identifiable {
    let newDraftOptions: NewDraftOptions?

    var isPhotosPickerPresented = false
    var isFileImporterPresented = false
    var isCameraPresented = false

    let id: UUID

    private var importTask: Task<Void, Error>?

    enum ImportStatus: Equatable {
        case importing(importedFiles: Int, totalFilesToImport: Int?)
        case finished(ImportResult)

        enum ImportResult: Equatable {
            case single(MediaFileDraft)
            case multi(MultiDraftInfo)
            case empty
        }

        var isImporting: Bool {
            switch self {
            case .importing(let importedFiles, let totalFilesToImport):
                if let totalFilesToImport {
                    importedFiles < totalFilesToImport
                } else {
                    true
                }
            case .finished:
                false
            }
        }
    }
    var importStatus: ImportStatus?

    var fileImporterOverlayOptions: FileImportProgressOverlayModifier.Options? {
        switch importStatus {
        case .importing(let importedFiles, let totalFilesToImport):
            if let totalFilesToImport, totalFilesToImport > 1 {
                // for single files the import should fast enough to show an overlay
                .init(value: importedFiles, total: totalFilesToImport)
            } else {
                nil
            }
        case .finished, nil:
            nil
        }
    }

    var photosPickerSelection: [PhotosPickerItem] = [] {
        didSet {
            handleNewPhotoItemSelection(oldValue: oldValue, currentValue: photosPickerSelection)
        }
    }

    private var importedItems: OrderedDictionary<MediaFileDraft.ID, MediaFileDraft>

    init(newDraftOptions: NewDraftOptions?) {
        id = .init()

        switch newDraftOptions?.source {
        case .mediaLibrary: isPhotosPickerPresented = true
        case .camera: isCameraPresented = true
        case .files: isFileImporterPresented = true
        case nil: break
        }

        self.newDraftOptions = newDraftOptions
        importStatus = nil
        importedItems = .init()
    }

    private func finalizeImport() {
        if importedItems.count > 1 {
            let multiDraftInfo = MultiDraftInfo(multiDraft: .init(newDraftOptions: newDraftOptions), drafts: Array(importedItems.values))
            importStatus = .finished(.multi(multiDraftInfo))
        } else if let draft = importedItems.values.first {
            importStatus = .finished(.single(draft))
        } else {
            importStatus = .finished(.empty)
            logger.warning("no import when finalizeImport() in FileImportModel")
        }
        importedItems.removeAll()
    }

    // NOTE: for this model, we expect selectionBehavior to be .ordered (or .default, but not .continuous)
    // so we expect this handler to only be called once when the user confirms their selection.
    func handleNewPhotoItemSelection(oldValue: [PhotosPickerItem], currentValue: [PhotosPickerItem]) {
        importStatus = .importing(importedFiles: 0, totalFilesToImport: nil)
        let photoItems = currentValue
        importTask?.cancel()
        importTask = Task<Void, Error> { [photoItems] in
            let totalFilesToImport = photoItems.count
            importStatus = .importing(
                importedFiles: 0,
                totalFilesToImport: totalFilesToImport
            )

            for photoItem in photoItems {
                try Task.checkCancellation()
                do {
                    let draft = try await MediaFileDraft.create(
                        fromPhotoItem: photoItem,
                        newDraftOptions: newDraftOptions,
                        isPartOfMultiDraft: photoItems.count > 1
                    )
                    try Task.checkCancellation()
                    importedItems[draft.id] = draft
                    importStatus = .importing(
                        importedFiles: importedItems.count,
                        totalFilesToImport: totalFilesToImport
                    )
                } catch {
                    logger.error("Failed to create draft of photo \(photoItem.itemIdentifier ?? ""): \(error)")
                }
            }

            finalizeImport()
        }
    }

    func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let fileURLs):
            importStatus = .importing(importedFiles: 0, totalFilesToImport: fileURLs.count)
            importTask = Task<Void, Error> {
                for url in fileURLs {
                    try Task.checkCancellation()
                    do {
                        let gotAccess = url.startAccessingSecurityScopedResource()
                        guard gotAccess else { throw FileImportError.fileAccessDenied(url) }
                        defer { url.stopAccessingSecurityScopedResource() }

                        let draft = try MediaFileDraft.create(
                            byCopyingFileAt: url,
                            newDraftOptions: newDraftOptions,
                            isPartOfMultiDraft: fileURLs.count > 1
                        )
                        importedItems[draft.id] = draft
                        importStatus = .importing(importedFiles: importedItems.count, totalFilesToImport: fileURLs.count)
                    } catch {
                        logger.error("Failed to import file. \(error)")
                    }
                }
                finalizeImport()
            }
        case .failure(let error):
            logger.error("error: \(error)")
            importStatus = nil
        }
    }

    func handleCameraImage(_ uiImage: UIImage, metadata: NSDictionary) throws {
        importStatus = .importing(importedFiles: 0, totalFilesToImport: 1)

        importTask = Task<Void, Error> {
            var cameraLocation: CLLocation?

            do {
                for try await locationUpdate in CLLocationUpdate.liveUpdates(.otherNavigation) {
                    if locationUpdate.locationUnavailable || locationUpdate.authorizationDenied || locationUpdate.authorizationDeniedGlobally {
                        break
                    }

                    if let location = locationUpdate.location {
                        cameraLocation = location
                        break
                    }
                }
            } catch {
                logger.info("Cannot get camera location")
            }

            let draft = try MediaFileDraft.create(
                fromImage: uiImage,
                metadata: metadata,
                location: cameraLocation,
                newDraftOptions: newDraftOptions,
                isPartOfMultiDraft: false
            )
            importedItems[draft.id] = draft
            finalizeImport()
        }
    }

    func onFileImportCancel() {
        importTask?.cancel()
        importedItems = .init()
        importStatus = .none
    }
}

// MARK: - Importing media files into new drafts
//
// Each factory writes the imported file to the new draft's `localFileURL()` inside the Documents directory.
// The draft itself is not stored in the database here; that only happens when the user saves it.
// Files of drafts that never get saved are removed by `Maintenance` at the next app launch.
extension MediaFileDraft {
    static let supportedPhotoMediaTypes: [UTType] = [.webP, .png, .jpeg, .gif]

    /// Expects the file to already be inside the app's container (eg. written by the ShareExtension) and moves it.
    static func create(byMovingFileAt url: URL, newDraftOptions: NewDraftOptions?, isPartOfMultiDraft: Bool) throws -> Self {
        let (draft, outURL) = try makeDraft(forFileAt: url, newDraftOptions: newDraftOptions, isPartOfMultiDraft: isPartOfMultiDraft)
        try FileManager.default.moveItem(at: url, to: outURL)
        return draft
    }

    /// Copies a file from outside the app's container (eg. picked in the Files app).
    /// The caller is responsible for holding security-scoped access to `url` while this runs.
    static func create(byCopyingFileAt url: URL, newDraftOptions: NewDraftOptions?, isPartOfMultiDraft: Bool) throws -> Self {
        let (draft, outURL) = try makeDraft(forFileAt: url, newDraftOptions: newDraftOptions, isPartOfMultiDraft: isPartOfMultiDraft)
        try FileManager.default.copyItem(at: url, to: outURL)
        return draft
    }

    /// Loads the photo's data from the Photos library and writes it to a new file.
    static func create(fromPhotoItem photoPickerItem: PhotosPickerItem, newDraftOptions: NewDraftOptions?, isPartOfMultiDraft: Bool) async throws -> Self {
        let fileType = photoPickerItem.supportedContentTypes.first { type in
            supportedPhotoMediaTypes.contains(type)
        }

        guard let fileType, fileType.preferredFilenameExtension != nil,
            let mimeType = fileType.preferredMIMEType
        else {
            logger.error("Unsupported content type: \(photoPickerItem.supportedContentTypes.debugDescription)")
            assertionFailure("In the photo picker we expect to always get supported types")
            throw FileImportError.unsupportedContentType(photoPickerItem.supportedContentTypes)
        }

        guard let data = try await photoPickerItem.loadTransferable(type: Data.self) else {
            throw FileImportError.failedToConvertPhotoItemToData
        }

        let exifData = try? ExifData(data: data)

        var draft = try MediaFileDraft(
            isPartOfMultiDraft: isPartOfMultiDraft,
            newDraftOptions: newDraftOptions,
            fileSize: Int64(data.count),
            fileType: fileType,
            exifData: exifData
        )
        draft.mimeType = mimeType

        guard let outURL = draft.localFileURL() else {
            throw FileImportError.failedToGetLocalFileURL
        }
        try data.write(to: outURL, options: [.atomic])

        return draft
    }

    /// Encodes the image as JPEG together with `metadata` (and the GPS location, if given) and writes it to a new file.
    static func create(
        fromImage uiImage: UIImage,
        metadata: NSDictionary,
        location: CLLocation?,
        newDraftOptions: NewDraftOptions?,
        isPartOfMultiDraft: Bool
    ) throws -> Self {
        guard let data = uiImage.jpegData(compressionQuality: 1),
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let type = CGImageSourceGetType(source),
            let imageRef = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw FileImportError.failedToConvertUIImageToData
        }

        let exifData = try ExifData(data: data)
        var draft = try MediaFileDraft(
            isPartOfMultiDraft: isPartOfMultiDraft,
            newDraftOptions: newDraftOptions,
            fileSize: Int64(data.count),
            fileType: .jpeg,
            exifData: exifData
        )
        draft.mimeType = UTType.jpeg.preferredMIMEType ?? "image/jpeg"

        guard let outURL = draft.localFileURL() else {
            throw FileImportError.failedToGetLocalFileURL
        }

        guard let destination = CGImageDestinationCreateWithURL(outURL as CFURL, type, 1, nil) else {
            throw FileImportError.failedToConvertUIImageToData
        }

        let metadata = NSMutableDictionary(dictionary: metadata)
        if let location {
            metadata[kCGImagePropertyGPSDictionary] = location.gpsDictionary
        }

        CGImageDestinationAddImage(destination, imageRef, metadata as CFDictionary)
        let success = CGImageDestinationFinalize(destination)
        if !success {
            throw FileImportError.failedToWriteImageWithMetadataToFile
        }

        return draft
    }

    /// Shared part of the file-URL based factories: validates the type and creates the draft (without touching the file).
    private static func makeDraft(
        forFileAt url: URL,
        newDraftOptions: NewDraftOptions?,
        isPartOfMultiDraft: Bool
    ) throws -> (draft: MediaFileDraft, outURL: URL) {
        let fileExtension = url.pathExtension
        guard let fileType = UTType(filenameExtension: fileExtension),
            let mimeType = fileType.preferredMIMEType
        else {
            throw FileImportError.unrecognizedFileType(fileExtension)
        }

        guard supportedPhotoMediaTypes.contains(fileType) else {
            throw FileImportError.unsupportedContentType([fileType])
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path()))?[.size] as? Int64
        let exifData = try? ExifData(url: url)

        var draft = try MediaFileDraft(
            isPartOfMultiDraft: isPartOfMultiDraft,
            newDraftOptions: newDraftOptions,
            fileSize: fileSize,
            fileType: fileType,
            exifData: exifData
        )
        draft.mimeType = mimeType

        guard let outURL = draft.localFileURL() else {
            throw FileImportError.failedToGetLocalFileURL
        }
        return (draft, outURL)
    }
}
