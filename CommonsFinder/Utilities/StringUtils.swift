//
//  ValidationUtils.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 19.11.24.
//

import Foundation

nonisolated enum ValidationUtils {
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

    static var disallowedPrefix: any RegexComponent {
        /^(BILD|CIMG|DSC_|DSCF|DSCN|DUW|IMG|JD|MGP|PICT|MG|IM0)/
    }

    static var disallowedCharacters: any RegexComponent {
        /[#<>\[\]\|:{}\\\/]/
    }

    static var multipleSpaces: any RegexComponent {
        /\s{2,}/
    }

    static var leadingTrailingSpaces: any RegexComponent {
        /^\s|\s$/
    }

    static var allCaps: any RegexComponent {
        /^\P{Ll}*$/
    }


    enum FilenameValidation {
        case ok
        case disallowedPrefix
        case disallowedCharacters
        case multipleSpaces
        case leadingTrailingSpaces
    }

    /// valiidates filetitles without "FILE:" prefix, and without filetype sufix (eg. ".jpg")
    static func validateFileTitle(_ filename: String) -> FilenameValidation {
        guard !filename.contains(disallowedPrefix) else { return .disallowedPrefix }
        guard !filename.contains(disallowedCharacters) else { return .disallowedCharacters }
        guard !filename.contains(multipleSpaces) else { return .multipleSpaces }
        guard !filename.contains(leadingTrailingSpaces) else { return .leadingTrailingSpaces }
        return .ok
    }

    /// This does basic sanitization but will not fix all possible cases
    static func sanitzieFileTitle(_ filename: String) -> String {
        var sanitized =
            filename
            .replacing(disallowedCharacters, with: "_")
            .replacing(disallowedPrefix, with: "")
            .replacing(multipleSpaces, with: "")
            .replacing(leadingTrailingSpaces, with: "")

        if sanitized.contains(allCaps) {
            sanitized = sanitized.localizedLowercase
        }


        return sanitized
    }
}
