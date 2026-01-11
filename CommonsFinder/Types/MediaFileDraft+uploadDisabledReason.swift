//
//  File.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 09.01.26.
//

import CommonsAPI
import UniformTypeIdentifiers
import os.log

extension MediaFileDraftModel {
    func canUploadDraft() -> UploadPossibleStatus? {
        return
            if draft.captionWithDesc.isEmpty
            || draft.captionWithDesc.allSatisfy({ captionDesc in
                captionDesc.caption.isEmpty && captionDesc.fullDescription.isEmpty
            })
        {
            .missingCaptionOrDescription
        } else if draft.license == nil {
            .missingLicense
        } else if draft.tags.isEmpty {
            .missingTags
        } else if let nameValidationResult {
            switch nameValidationResult {
            case .failure(let nameValidationError):
                .validationError(nameValidationError)
            case .success(_):
                .uploadPossible
            }
        } else {
            .failedToValidate
        }
    }

    func validateFilename() async -> NameValidationResult {
        let localValidationResult = LocalFileNameValidation.validateFileName(draft.name)
        return switch localValidationResult {
        case .success:
            // if local validation was successful, check again with API
            await validateFilenameWithAPI() ?? .success(())
        case .failure(let error):
            .failure(.invalid(error))
        }
    }

    private func validateFilenameWithAPI() async -> NameValidationResult? {
        // iOS26 target: move into an Observation on draft.name
        guard let uniformType = UTType(mimeType: draft.mimeType) else {
            assertionFailure("We expect drafts to always have a correct mimetype")
            return nil
        }


        // The API operates on filenames with type-endings (.jpg, .png, etc.)
        let filename = draft.name.appendingFileExtension(conformingTo: uniformType)

        do {
            async let existsTask = CommonsAPI.API.shared.checkIfFileExists(
                filename: filename
            )
            async let validationTask = CommonsAPI.API.shared.validateFilename(
                filename: filename
            )

            let (existsResult, validationResult) = try await (existsTask, validationTask)

            switch existsResult {
            case .exists: return .failure(.alreadyExists)
            case .invalidFilename: return .failure(.invalid(nil))
            case .doesNotExist:
                switch validationResult {
                case .disallowed: return .failure(.disallowed)
                case .invalid: return .failure(.invalid(nil))
                case .ok: return .success(())
                case .unknownOther: return .failure(.undefinedAPIResult)
                }
            }
        } catch {
            logger.error("Failed to validate filename \(error)")
            return .failure(.undefinedAPIResult)
        }
    }
}
