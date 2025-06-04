//
//  FileItem.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 08.11.24.
//

import CryptoKit
import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import os.log

enum FileImportError: Error {
    case fileAccessDenied(URL)
    case failedToConvertDataToUrl
    case failedToConvertPhotoItemToData
    case failedToConvertUIImageToData
    case failedToWriteImageWithMetadataToFile
    case unrecognizedFileType(String)
    case unsupportedContentType([UTType])
    case failedToDetermineFileExtension(UTType)

}


struct FileItem: Equatable, Hashable, Identifiable, Sendable {
    static let supportedPhotoMediaTypes: [UTType] = [.svg, .webP, .png, .jpeg, .gif]

    var id: String { localFileName }
    let localFileName: String
    let originalFilename: String?
    let fileType: UTType

    /// synthesized file-URL inside App's Documents directory, based on `fileName`.
    var fileURL: URL { URL.documentsDirectory.appending(path: id) }

    /// The photosPicker itemIdentifier.
    let itemIdentifier: String?

    /// This will create a copy of the file in the local app directory
    init(copyingDataFromLocalFile originalFileURL: URL) throws {
        let fileExtension = originalFileURL.pathExtension
        guard let fileType = UTType(filenameExtension: fileExtension) else {
            throw FileImportError.unrecognizedFileType(fileExtension)
        }

        guard FileItem.supportedPhotoMediaTypes.contains(fileType) else {
            throw FileImportError.unsupportedContentType([fileType])
        }

        localFileName = UUID().uuidString.appendingFileExtension(conformingTo: fileType)
        itemIdentifier = nil

        let gotAccess = originalFileURL.startAccessingSecurityScopedResource()
        guard gotAccess else { throw FileImportError.fileAccessDenied(originalFileURL) }
        originalFilename = originalFileURL.lastPathComponent

        self.fileType = fileType

        try FileManager()
            .copyItem(
                at: originalFileURL,
                to: fileURL
            )

        originalFileURL.stopAccessingSecurityScopedResource()
    }

    /// Creates JPG-Data and writes them to a file
    init(uiImage: UIImage, metadata: NSDictionary, location: CLLocation?) throws {
        guard let data = uiImage.jpegData(compressionQuality: 1),
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let type = CGImageSourceGetType(source),
            let imageRef = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw FileImportError.failedToConvertUIImageToData
        }


        originalFilename = nil
        fileType = .jpeg
        localFileName = UUID().uuidString.appendingFileExtension(conformingTo: fileType)
        itemIdentifier = nil

        guard let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, type, 1, nil) else {
            throw FileImportError.failedToConvertUIImageToData
        }

        let metadata = NSMutableDictionary(dictionary: metadata)
        if let location {
            metadata[kCGImagePropertyGPSDictionary] = location.gpsDictionary
        }

        CGImageDestinationAddImage(destination, imageRef, metadata as CFDictionary)
        let success = CGImageDestinationFinalize(destination)
        if !success {
            throw FileImportError.failedToWriteImageWithMetadataToFile
        }
    }

    /// This will create a copy of the file in the local app directory
    init(photoPickerItem: PhotosPickerItem) async throws {
        self.originalFilename = nil

        let fileType = photoPickerItem.supportedContentTypes.first { type in
            FileItem.supportedPhotoMediaTypes.contains(type)
        }

        guard let fileType, fileType.preferredFilenameExtension != nil else {
            logger.error("Unsupported content type: \(photoPickerItem.supportedContentTypes.debugDescription)")
            assertionFailure("In the photo picker we expect to always get supported types")
            throw FileImportError.unsupportedContentType(photoPickerItem.supportedContentTypes)
        }

        guard let data = try await photoPickerItem.loadTransferable(type: Data.self) else {
            throw FileImportError.failedToConvertPhotoItemToData
        }

        self.fileType = fileType

        self.itemIdentifier = photoPickerItem.itemIdentifier
        self.localFileName = UUID().uuidString.appendingFileExtension(conformingTo: fileType)

        try data.write(
            to: fileURL,
            options: [.atomic, .completeFileProtection]
        )
    }

    /// This expects the file to already copied into the local App container, so it just needs to be moved
    /// **Used for files created by the ShareExtension**
    init(movingLocalFileFromPath originalPath: URL) throws {
        let fileManager = FileManager()
        var newPath = URL.documentsDirectory.appending(component: originalPath.lastPathComponent)
        if fileManager.fileExists(atPath: newPath.absoluteString) {
            newPath =
                newPath
                .deletingLastPathComponent()
                .appending(component: UUID().uuidString + "." + newPath.lastPathComponent)
        }
        try fileManager.moveItem(at: originalPath, to: newPath)

        self.localFileName = newPath.lastPathComponent
        let fileExtension = newPath.pathExtension
        guard let fileType = UTType(filenameExtension: fileExtension),
            FileItem.supportedPhotoMediaTypes.contains(fileType)
        else {
            throw FileImportError.unrecognizedFileType(fileExtension)
        }

        self.fileType = fileType
        itemIdentifier = nil
        self.originalFilename = originalPath.lastPathComponent
    }

}
