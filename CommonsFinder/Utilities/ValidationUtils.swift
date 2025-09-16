//
//  ValidationUtils.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 19.11.24.
//

import Foundation

enum ValidationUtils {
    nonisolated static func isValidEmailAddress(string: String) -> Bool {
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
