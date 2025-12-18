//
//  FilenameTests.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 18.12.25.
//

import Foundation
import Testing

// See: https://commons.wikimedia.org/wiki/Commons:File_naming/en
// See also: https://commons.wikimedia.org/wiki/MediaWiki:Titleblacklist

/// without filetype ending (.jpg, etc.)
nonisolated private let badFileTitles: [String] = [
    "test   ",
    "Foo:bar",
    "foo|bar",
    "foo/bar/blub",
    "  F_test{or something} } blub (bar) ",
    " ALL:CAPS.JPG",
]

@Test(arguments: badFileTitles)
func testBadFileSanitization(badFilename: String) {
    let initialValidation = ValidationUtils.validateFileTitle(badFilename)
    #expect(initialValidation != .ok)
    let sanitized = ValidationUtils.sanitzieFileTitle(badFilename)
    let validation = ValidationUtils.validateFileTitle(sanitized)
    print("\(badFilename) -> \(sanitized)")
    #expect(validation == .ok)
}
