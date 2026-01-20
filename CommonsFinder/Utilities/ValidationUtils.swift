//
//  ValidationUtils.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 19.11.24.
//

import Foundation

nonisolated enum EmailValidation {
    static func isValidEmailAddress(string: String) -> Bool {
        let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        )

        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        let matches = detector?.matches(in: string, options: [], range: range)

        // Make sure we have exactly 1 match
        guard let match = matches?.first, matches?.count == 1 else {
            return false
        }

        // ...And that match must be a mail (returned as a mailto: link by the DataDetector)
        guard match.url?.scheme == "mailto", match.range == range else {
            return false
        }

        return true
    }
}

nonisolated enum LocalFileNameValidation {
    static let minCharLength = 5

    static var disallowedPrefixPattern: any RegexComponent {
        /^(BILD|CIMG|DSC_|DSCF|DSCN|DUW|IMG|JD|MGP|PICT|MG|IM0)/
    }

    static var disallowedCharactersPattern: any RegexComponent {
        /[#<>\[\]\|:{}\\\/]/
    }

    static var multipleSpacesPattern: any RegexComponent {
        /\s{2,}/
    }

    static var leadingTrailingSpacesPattern: any RegexComponent {
        /^\s|\s$/
    }
    static var leadingTrailingUnderscorePattern: any RegexComponent {
        /^_|_$/
    }

    static var onlyRepeatingCharactersPattern: any RegexComponent {
        /^(.)\1*$/
    }

    /// valiidates filenames without "FILE:" prefix, and without filetype sufix (eg. ".jpg"), for
    static func validateFileName(_ filename: String) -> Result<Void, LocalFilenameValidationError> {
        guard filename.count >= minCharLength else { return .failure(.tooShort) }
        guard !filename.contains(disallowedPrefixPattern) else { return .failure(.disallowedPrefix) }
        guard !filename.contains(disallowedCharactersPattern) else { return .failure(.disallowedCharacters) }
        guard !filename.localizedLowercase.contains(onlyRepeatingCharactersPattern) else { return .failure(.onlyRepeatingCharacters) }
        guard !filename.contains(leadingTrailingSpacesPattern) else { return .failure(.leadingTrailingSpaces) }
        return .success(())
    }

    /// This does basic sanitization but will not fix all possible cases
    /// full: true will also replace leading and trailing spaces amd multiple spaces in a row
    static func sanitizeFileName(_ filename: String, replaceExtraSpaces: Bool = true) -> String {
        var sanitized =
            filename
            .replacing(disallowedCharactersPattern, with: "")
            .replacing(leadingTrailingUnderscorePattern, with: "")
            .replacing(disallowedPrefixPattern, with: "")

        if replaceExtraSpaces {
            sanitized =
                sanitized
                .replacing(multipleSpacesPattern, with: "")
                .replacing(leadingTrailingSpacesPattern, with: "")
        }

        return sanitized
    }
}

nonisolated enum LocalFilenameValidationError: String, Error, Sendable, Codable, Equatable, Hashable {
    case tooShort
    case disallowedPrefix
    case disallowedCharacters
    case onlyRepeatingCharacters
    case leadingTrailingSpaces

    static let autoFixable: Set<Self> = [.disallowedPrefix, .disallowedCharacters, .leadingTrailingSpaces]

    var canBeAutoFixed: Bool { Self.autoFixable.contains(self) }
}
