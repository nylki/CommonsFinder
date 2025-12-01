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

// An actor to handle reads and write on local files
@globalActor actor FileStorageActor: GlobalActor {
    static let shared = FileStorageActor()
}

/// DraftModel models a drafting session where the user can add & remove files and also edit their metadata
@Observable class FileCreateViewModel {
    private var photoImportTask: Task<Void, Error>?
    let newDraftOptions: NewDraftOptions?

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

    var canSafeDrafts: Bool {
        !editedDrafts.isEmpty
            && editedDrafts.allSatisfy { _, value in
                !value.draft.name.isEmpty
            }
    }

    var fileCount: Int {
        photosPickerSelection.count + editedDrafts.count
    }

    var draftsExistInDB: Bool = false

    private let appDatabase: AppDatabase

    init(appDatabase: AppDatabase, newDraftOptions: NewDraftOptions?) {
        self.appDatabase = appDatabase
        self.newDraftOptions = newDraftOptions
        editedDrafts = .init()
    }

    convenience init(appDatabase: AppDatabase, existingDrafts: [MediaFileDraft], newDraftOptions: NewDraftOptions? = nil) {
        self.init(appDatabase: appDatabase, newDraftOptions: newDraftOptions)
        for existingDraft in existingDrafts {
            let model = MediaFileDraftModel(existingDraft: existingDraft)
            editedDrafts[model.id] = model
        }
        if !existingDrafts.isEmpty {
            // Check if drafts are known to the DB
            // TODO: maybe init from ID in the first place?
            do {
                draftsExistInDB = try appDatabase.reader.read {
                    try existingDrafts.count
                        == MediaFileDraft
                        .filter(ids: existingDrafts.map(\.id))
                        .fetchCount($0)
                }
            } catch {
                logger.error("Failed to check if drafts exist in DB \(error)")
            }
        }
    }

    func handleNewPhotoItemSelection(oldValue: [PhotosPickerItem], currentValue: [PhotosPickerItem]) {
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
                    let draft = MediaFileDraftModel(fileItem: fileItem, newDraftOptions: newDraftOptions)
                    editedDrafts[draft.id] = draft
                } catch {
                    logger.error("Failed to create fileItem of photo \(photoItem.itemIdentifier ?? ""): \(error)")
                }
            }
        }
    }

    func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let fileURLs):
            Task<Void, Error> {
                for url in fileURLs {
                    do {
                        let fileItem = try await loadFileItem(url: url)
                        let newDraft = MediaFileDraftModel(fileItem: fileItem, newDraftOptions: newDraftOptions)
                        editedDrafts[newDraft.id] = newDraft
                    } catch {
                        logger.error("Failed to import file. \(error)")
                    }
                }
            }
        case .failure(let error):
            logger.error("error: \(error)")
        }
    }

    func handleCameraImage(_ uiImage: UIImage, metadata: NSDictionary) throws {

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
            let newDraft = MediaFileDraftModel(fileItem: fileItem, newDraftOptions: newDraftOptions)

            editedDrafts[newDraft.id] = newDraft
        }

    }

    private func loadFileItem(url: URL) async throws -> FileItem {
        assert(url.isFileURL, "This function only expects file URLs.")
        return try FileItem(copyingDataFromLocalFile: url)
    }

    func saveAllChanges() throws {
        for draftModel in editedDrafts.values {
            if let fileItem = draftModel.fileItem {
                draftModel.draft.localFileName = fileItem.localFileName
            }

            try appDatabase.upsert(draftModel.draft)
        }
    }

    func deleteDrafts() throws {
        try appDatabase.delete(editedDrafts.values.map(\.draft))
    }
}
