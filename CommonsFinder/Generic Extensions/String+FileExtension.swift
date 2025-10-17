//
//  String+FileExtension.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 08.11.24.
//

import Foundation
import UniformTypeIdentifiers

nonisolated
    extension String
{
    func fileName() -> String {
        URL(filePath: self).deletingPathExtension().lastPathComponent
    }

    func fileExtension() -> String {
        URL(filePath: self).pathExtension
    }

    /// constructs full filename with extension (eg. "test file 123", .jpeg) -> "test file 123.jpg", makes sure to not add it if it exists alreadsy
    func appendingFileExtension(conformingTo type: UTType) -> String {
        URL(filePath: "")
            .appendingPathComponent(self, conformingTo: type)
            .lastPathComponent
    }

    /// constructs full filename with extension (eg. "test file 123", .jpeg) -> "test file 123.jpg", makes sure to not add it if it exists alreadsy
    static func appendingFileExtension(fileName: String, conformingTo type: UTType) -> String {
        URL(filePath: "")
            .appendingPathComponent(fileName, conformingTo: type)
            .lastPathComponent
    }
}
