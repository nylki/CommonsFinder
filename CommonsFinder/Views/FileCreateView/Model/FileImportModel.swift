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
    private var photoImportTask: Task<Void, Error>?
    let newDraftOptions: NewDraftOptions?

    var isPhotosPickerPresented = false
    var isFileImporterPresented = false
    var isCameraPresented = false

    let id: UUID

    enum ImportStatus: Equatable {
        case importing
        case finished
    }
    var importStatus: ImportStatus?

    /// The currently centered file in the scrollView that is being edited
    var selectedID: MediaFileDraftModel.ID?

    var photosPickerSelection: [PhotosPickerItem] = [] {
        didSet {
            handleNewPhotoItemSelection(oldValue: oldValue, currentValue: photosPickerSelection)
        }
    }

    var importedDrafts: OrderedDictionary<MediaFileDraft.ID, MediaFileDraft>
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
        importedDrafts = .init()
    }

    func handleNewPhotoItemSelection(oldValue: [PhotosPickerItem], currentValue: [PhotosPickerItem]) {
        importStatus = .importing

        photoImportTask?.cancel()
        let itemIDs = Set(currentValue.compactMap(\.itemIdentifier))
        let oldItemIDs = Set(oldValue.compactMap(\.itemIdentifier))
        let addedItemIDs = itemIDs.subtracting(oldItemIDs)
        let removedItemIDs = oldItemIDs.subtracting(itemIDs)
        // remove all previously imported items that are not in the selection anymore

        removedItemIDs.forEach { id in
            importedDrafts.removeValue(forKey: id)
        }

        photoImportTask = Task<Void, Error> {
            let photoItems = currentValue.filter {
                if let itemIdentifier = $0.itemIdentifier {
                    addedItemIDs.contains(itemIdentifier)
                } else {
                    false
                }
            }

            // import data for all new files
            for photoItem in photoItems {
                do {
                    let fileItem = try await FileItem.init(photoPickerItem: photoItem)
                    try Task.checkCancellation()
                    let draft = try MediaFileDraft(fileItem, newDraftOptions: newDraftOptions)
                    importedDrafts[draft.id] = draft
                } catch {
                    logger.error("Failed to create fileItem of photo \(photoItem.itemIdentifier ?? ""): \(error)")
                }
            }
            importStatus = .finished
        }
    }

    func handleFileImport(result: Result<[URL], Error>) {
        importStatus = .importing

        switch result {
        case .success(let fileURLs):
            Task<Void, Error> {
                for url in fileURLs {
                    do {
                        let fileItem = try await loadFileItem(url: url)
                        let draft = try MediaFileDraft(fileItem, newDraftOptions: newDraftOptions)
                        importedDrafts[draft.id] = draft
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
        importStatus = .importing
        Task {
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
            let draft = try MediaFileDraft(fileItem, newDraftOptions: newDraftOptions)
            importedDrafts[draft.id] = draft
            importStatus = .finished
        }

    }

    private func loadFileItem(url: URL) async throws -> FileItem {
        assert(url.isFileURL, "This function only expects file URLs.")
        return try FileItem(copyingDataFromLocalFile: url)
    }
}
