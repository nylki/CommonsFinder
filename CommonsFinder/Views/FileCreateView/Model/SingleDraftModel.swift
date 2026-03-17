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

// TODO: perhaps consolidate as view state directly
@Observable final class SingleDraftModel: @preconcurrency Identifiable {
    typealias ID = String
    var id: ID
    var draft: MediaFileDraft

    var suggestedFilenames: [FileNameTypeTuple] = []
    var nameValidationResult: NameValidationResult?

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

    func validateFilenameImpl() async throws {
        nameValidationResult = nil
        draft.uploadPossibleStatus = nil
        try await Task.sleep(for: .milliseconds(500))
        nameValidationResult = await DraftValidation.validateFilename(name: draft.name, mimeType: draft.mimeType)
        draft.uploadPossibleStatus = DraftValidation.canUploadDraft(draft, nameValidationResult: nameValidationResult)
    }
}

typealias NameValidationResult = Result<Void, NameValidationError>

extension NameValidationResult {
    var error: NameValidationError? {
        switch self {
        case .success: return nil
        case .failure(let error): return error
        }
    }

    var alertTitle: String? {
        if let error {
            switch error {
            case .invalid(_):
                error.failureReason
            default:
                error.errorDescription
            }
        } else {
            nil
        }
    }
}
