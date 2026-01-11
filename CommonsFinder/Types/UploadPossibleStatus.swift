//
//  UploadPossibleStatus.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 08.01.26.
//


import Foundation

nonisolated enum UploadPossibleStatus: Codable, Equatable, Hashable {
    case uploadPossible
    case notLoggedIn
    case missingCaptionOrDescription
    case missingLicense
    case missingTags
    case validationError(NameValidationError)
    case failedToValidate
}
