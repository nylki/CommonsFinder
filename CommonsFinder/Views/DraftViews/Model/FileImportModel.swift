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

/// DraftModel models a drafting session where the user can add & remove files and also edit their metadata
@Observable class FileImportModel: Identifiable {
    private var importTask: Task<Void, Error>?
    let newDraftOptions: NewDraftOptions?

    var isPhotosPickerPresented = false
    var isFileImporterPresented = false
    var isCameraPresented = false

    let id: UUID

    enum ImportStatus: Equatable {
        case importing(importedFiles: Int, totalFilesToImport: Int?)
        case finished

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

    var importedItems: OrderedDictionary<FileItem.ID, FileItem>
    //    var draftsExistInDB: Bool = false


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

    func handleNewPhotoItemSelection(oldValue: [PhotosPickerItem], currentValue: [PhotosPickerItem]) {
        importStatus = .importing(importedFiles: 0, totalFilesToImport: nil)

        importTask?.cancel()
        let itemIDs = Set(currentValue.compactMap(\.itemIdentifier))
        let oldItemIDs = Set(oldValue.compactMap(\.itemIdentifier))
        let addedItemIDs = itemIDs.subtracting(oldItemIDs)
        let removedItemIDs = oldItemIDs.subtracting(itemIDs)
        // remove all previously imported items that are not in the selection anymore

        removedItemIDs.forEach { id in
            importedItems.removeValue(forKey: id)
        }

        importTask = Task<Void, Error> {
            let photoItems = currentValue.filter {
                if let itemIdentifier = $0.itemIdentifier {
                    addedItemIDs.contains(itemIdentifier)
                } else {
                    false
                }
            }

            importStatus = .importing(importedFiles: 0, totalFilesToImport: photoItems.count)

            // import data for all new files
            for photoItem in photoItems {
                try Task.checkCancellation()
                do {
                    let fileItem = try await FileItem.init(photoPickerItem: photoItem)
                    try Task.checkCancellation()
                    importedItems[fileItem.id] = fileItem
                    importStatus = .importing(importedFiles: importedItems.count, totalFilesToImport: photoItems.count)
                } catch {
                    logger.error("Failed to create fileItem of photo \(photoItem.itemIdentifier ?? ""): \(error)")
                }
            }
            importStatus = .finished
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
                        let fileItem = try await loadFileItem(url: url)
                        importedItems[fileItem.id] = fileItem
                        importStatus = .importing(importedFiles: importedItems.count, totalFilesToImport: fileURLs.count)
                    } catch {
                        logger.error("Failed to import file. \(error)")
                    }
                }
                importStatus = .finished
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


            let fileItem = try FileItem.init(uiImage: uiImage, metadata: metadata, location: cameraLocation)
            importedItems[fileItem.id] = fileItem
            importStatus = .finished
        }

    }

    func onFileImportCancel() {
        importTask?.cancel()
        importedItems = .init()
        importStatus = .none
    }

    private func loadFileItem(url: URL) async throws -> FileItem {
        assert(url.isFileURL, "This function only expects file URLs.")
        return try FileItem(copyingDataFromLocalFile: url)
    }
}
