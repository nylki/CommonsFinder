//
//  MediaFileDraftModel.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 13.10.24.
//

import CommonsAPI
import CoreLocation
import Foundation
import Nuke
import UniformTypeIdentifiers
import Vision
import os.log

/// Represents the data to allow editing either a DB-backed MediaFile or a newly created one.
@Observable final class MediaFileDraftModel: @preconcurrency Identifiable {
    typealias ID = String
    var id: ID
    var draft: MediaFileDraft
    let addedDate: Date

    var isShowingTagsPicker = false
    var isShowingCategoryPicker = false

    enum ImageAnalysisStatus: Equatable {
        case none
        case analyzing
        case finished(ImageAnalysisResult?)

        var result: ImageAnalysisResult? {
            if case .finished(let res) = self { res } else { nil }
        }
    }

    var analysisResult: ImageAnalysisStatus = .none

    var suggestedFilenames: [FileNameTypeTuple] = []
    var nameValidationResult: NameValidationResult?

    /// If a draft has just been created and does not have its media file backed on disk in the apps directory
    /// this holds the information about filename, filetype and Data.
    var fileItem: FileItem?

    @ObservationIgnored
    lazy var exifData: ExifData? = {
        draft.loadExifData()
    }()

    init(fileItem: FileItem, newDraftOptions: NewDraftOptions?) throws {
        addedDate = .now
        var draft = try MediaFileDraft(fileItem)
        if let initialTag = newDraftOptions?.tag {
            draft.tags = [initialTag]
        }
        self.id = fileItem.id
        self.draft = draft
        self.fileItem = fileItem
    }

    /// Use an already fully initialized draft
    init(existingDraft: MediaFileDraft) {
        addedDate = .now
        id = existingDraft.id
        draft = existingDraft
    }

    // TODO: always copy to disk. Because re-opening drafts will also read from Disk.
    private var imageLoadTask: Task<Void, Never>?

    // TODO: move to parent, to handle potentially multiple drafts at once
    func analyzeImage(appDatabase: AppDatabase) async {
        switch analysisResult {
        case .none: break
        case .analyzing, .finished(_): return
        }

        analysisResult = .analyzing

        logger.debug("analyzing draft image...")
        let result = await ImageAnalysis.analyze(draft: draft, appDatabase: appDatabase)
        logger.debug("analyzing draft image finished! \(result?.debugDescription ?? "")")
        self.analysisResult = .finished(result)
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
        nameValidationResult = await validateFilename()
        draft.uploadPossibleStatus = canUploadDraft()
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

enum NameValidationError: LocalizedError, Codable, Hashable, Equatable {
    case alreadyExists
    case disallowed
    case invalid(LocalFilenameValidationError?)
    case undefinedAPIResult


    var errorDescription: String? {
        switch self {
        case .alreadyExists:
            String(localized: "the filename already exists")
        case .disallowed:
            String(localized: "the filename contains invalid character sequences or blocked words")
        case .invalid:
            String(localized: "the filename is invalid")
        case .undefinedAPIResult:
            String(localized: "failed to validate file name due to an unknown error")
        }
    }

    var failureReason: String? {
        switch self {
        case .alreadyExists:
            String(localized: "filenames must be unique on the server")
        case .disallowed:
            String(localized: "some words or combinations of characters have been blocked on the server either because they are to generic and non-descript or due to other reasons.")
        case .invalid(let localValidationError):
            switch localValidationError {
            case .tooShort:
                String(localized: "The filename is too short (5+ characters)")
            case .disallowedPrefix:
                String(localized: "The filename starts with a disallowed prefix")
            case .disallowedCharacters:
                String(localized: "The filename contains one or more reserved characters (|:#<>[]{}\\)")
            case .onlyRepeatingCharacters:
                String(localized: "The filename consists only of the same repeated character")
            case .leadingTrailingSpaces:
                String(localized: "The filename contains extra spaces at the start or end")
            case .none:
                String(localized: "Certain characters are reserved due to technical reasons and cannot be used for file names")
            }

        case .undefinedAPIResult:
            nil
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .alreadyExists:
            String(localized: "Please choose a more unique name. For example you could add the date, location, an event name or a number.")
        case .disallowed:
            String(localized: "Please choose a different name.")
        case .invalid(let localValidationError):
            switch localValidationError {
            case .tooShort:
                String(localized: "Please choose a longer and more descriptive filename.")
            case .disallowedPrefix:
                String(localized: "Choose a descriptive filename without the current prefix.")
            case .disallowedCharacters:
                String(localized: "Please remove the disallowed characters.")
            case .onlyRepeatingCharacters:
                String(localized: "Please choose a descriptive and meaningful filename.")
            case .leadingTrailingSpaces:
                String(localized: "Please remove the extra spaces from the filename.")
            case nil:
                String(localized: "Please choose a different filename.")

            }
        case .undefinedAPIResult:
            nil
        }
    }

    var helpAnchor: String? {
        switch self {
        case .alreadyExists:
            String(localized: "Edit the name to make it unique, You could add the date, location, event name or a number.")
        case .disallowed:
            String(localized: "Choose a different name.")
        case .invalid:
            String(localized: "the filename contains invalid words")
        case .undefinedAPIResult:
            nil
        }
    }
}
