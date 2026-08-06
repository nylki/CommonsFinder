//
//  SingleDraftModel.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 13.10.24.
//

import CommonsAPI
import CoreLocation
import Foundation
import Nuke
import UniformTypeIdentifiers
import os.log

enum SingleDraftModelError: Error {
    case cannotSaveEditsAfterDraftAlreadyPublished
}

@Observable final class SingleDraftModel: @preconcurrency Identifiable {
    typealias ID = String
    var id: ID
    var draft: MediaFileDraft

    var suggestedFilenames: [FileNameTypeTuple] = []
    var nameValidationResult: NameValidationResult?

    private var generateFilenameTask: Task<Void, Never>?

    @ObservationIgnored
    lazy var exifData: ExifData? = {
        draft.loadExifData()
    }()

    /// Use an already fully initialized draft
    init(existingDraft: MediaFileDraft) {
        id = existingDraft.id
        draft = existingDraft
    }

    var choosenCoordinate: CLLocationCoordinate2D? {
        return switch draft.locationHandling {
        case .userDefinedLocation(latitude: let lat, longitude: let lon, _):
            .init(latitude: lat, longitude: lon)
        case .exifLocation:
            exifData?.coordinate
        case .noLocation:
            nil
        case .none:
            nil
        }
    }

    func generateFilename() {
        generateFilenameTask?.cancel()
        generateFilenameTask = Task<Void, Never> {
            try? await Task.sleep(for: .milliseconds(250))

            let generatedFilename =
                await draft.selectedFilenameType.generateFilename(
                    coordinate: exifData?.coordinate,
                    date: draft.inceptionDate,
                    desc: draft.captionWithDesc,
                    locale: Locale.current,
                    tags: draft.tags
                ) ?? draft.name

            guard !Task.isCancelled else {
                generateFilenameTask = nil
                return
            }

            draft.name = generatedFilename
        }
    }

    func validateFilenameImpl() async throws {
        // FIXME: combine with general .onChangeOf(draft)
        // and check conditionally if newValue.name != oldValue.name to validate filename
        nameValidationResult = nil
        draft.uploadPossibleStatus = nil
        try await Task.sleep(for: .milliseconds(500))
        nameValidationResult = await DraftValidation.validateFilename(name: draft.name, mimeType: draft.mimeType)
        draft.uploadPossibleStatus = DraftValidation.canUploadDraft(draft, nameValidationResult: nameValidationResult)
    }

    func saveEditingChanges(appDatabase: AppDatabase) throws {
        guard draft.publishingState != .published else {
            throw SingleDraftModelError.cannotSaveEditsAfterDraftAlreadyPublished
        }

        // Any edit invalidates a prior publishing attempt, so reset the publishing
        // state/error for the UI and the "startStep" decision in UploadManager.
        draft.publishingError = nil
        draft.publishingState = nil
        draft.publishingStateVerificationRequired = false

        draft = try appDatabase.upsert(draft)
    }
}
