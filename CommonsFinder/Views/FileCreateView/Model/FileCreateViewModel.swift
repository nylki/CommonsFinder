//
//  DraftModel.swift
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
@Observable class FileCreateViewModel: Identifiable {
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

    var editedDrafts: OrderedDictionary<MediaFileDraftModel.ID, MediaFileDraftModel>
    var selectedDraft: MediaFileDraftModel? {
        if let selectedID {
            editedDrafts[selectedID]
        } else {
            nil
        }
    }

    var fileCount: Int {
        photosPickerSelection.count + editedDrafts.count
    }

    //    var draftsExistInDB: Bool = false


    init(newDraftOptions: NewDraftOptions?) {
        self.id = .init()

        switch newDraftOptions?.source {
        case .mediaLibrary: isPhotosPickerPresented = true
        case .camera: isCameraPresented = true
        case .files: isFileImporterPresented = true
        case nil: break
        }

        self.newDraftOptions = newDraftOptions
        self.importStatus = nil

        editedDrafts = .init()
    }

    convenience init(existingDrafts: [MediaFileDraft], newDraftOptions: NewDraftOptions? = nil) {
        self.init(newDraftOptions: newDraftOptions)
        importStatus = .finished

        for existingDraft in existingDrafts {
            let model = MediaFileDraftModel(existingDraft: existingDraft)
            editedDrafts[model.id] = model
        }
        if !existingDrafts.isEmpty {
            // Check if drafts are known to the DB
            // TODO: maybe init from ID in the first place?
            //            do {
            //                draftsExistInDB = try appDatabase.reader.read {
            //                    try existingDrafts.count
            //                        == MediaFileDraft
            //                        .filter(ids: existingDrafts.map(\.id))
            //                        .fetchCount($0)
            //                }
            //            } catch {
            //                logger.error("Failed to check if drafts exist in DB \(error)")
            //            }
        }
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
            editedDrafts.removeValue(forKey: id)
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
                    let draft = try MediaFileDraftModel(fileItem: fileItem, newDraftOptions: newDraftOptions)
                    editedDrafts[draft.id] = draft
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
                        let newDraft = try MediaFileDraftModel(fileItem: fileItem, newDraftOptions: newDraftOptions)
                        editedDrafts[newDraft.id] = newDraft
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
            let newDraft = try MediaFileDraftModel(fileItem: fileItem, newDraftOptions: newDraftOptions)

            editedDrafts[newDraft.id] = newDraft
            importStatus = .finished
        }

    }

    private func loadFileItem(url: URL) async throws -> FileItem {
        assert(url.isFileURL, "This function only expects file URLs.")
        return try FileItem(copyingDataFromLocalFile: url)
    }
}
