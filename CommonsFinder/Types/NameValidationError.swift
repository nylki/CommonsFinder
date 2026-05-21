//
//  NameValidationError.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.03.26.
//

import Foundation
import SwiftUI

enum NameValidationError: LocalizedError, Codable, Hashable, Equatable {
    case alreadyExists(filenames: [String])
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
        case .alreadyExists(let filenames):
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
            case .disallowedMimetype:
                String(localized: "The file type is not supported.")
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
            case .disallowedMimetype:
                String(localized: "The file must be converted to a supported format before uploading.")
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
