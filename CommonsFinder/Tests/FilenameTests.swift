//
//  FilenameTests.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 18.12.25.
//

import Foundation
import Testing
import UniformTypeIdentifiers

// See: https://commons.wikimedia.org/wiki/Commons:File_naming/en
// See also: https://commons.wikimedia.org/wiki/MediaWiki:Titleblacklist

/// without filetype ending (.jpg, etc.)
nonisolated private let badFileTitles: [String] = [
    "test1234   ",
    "Foo:bar",
    "foo|bar",
    "foo/bar/blub",
    "  F_test{or something} } blub (bar) ",
    " ALL:CAPS.JPG",
]

@Test(arguments: badFileTitles)
func testBadFileSanitization(badTitle: String) {
    let badFilename = badTitle.appendingFileExtension(conformingTo: .jpeg)
    switch LocalFileNameValidation.validateFilenameWithSuffix(badFilename) {
    case .success(_): Issue.record("\(badFilename) succeded, but is expected to be bad.")
    case .failure(_): break
    }

    let sanitized =
        LocalFileNameValidation
        .sanitizeFileName(badTitle)
        .appendingFileExtension(conformingTo: .jpeg)

    switch LocalFileNameValidation.validateFilenameWithSuffix(sanitized) {
    case .success(_): break
    case .failure(let failure): Issue.record(failure)
    }
}
