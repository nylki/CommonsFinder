//
//  MediaDownloading.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.10.25.
//

import Foundation
import Nuke
import Photos
import PhotosUI
import UniformTypeIdentifiers
import os.log

extension MediaFileInfo {
    @concurrent func saveToPhotos() async throws {
        let data = try await ImagePipeline.shared.data(for: originalImageRequest()).0

        let contentType: UTType? =
            if let mimeType = mediaFile.mimeType {
                UTType(mimeType: mimeType)
            } else {
                nil
            }
        let photoLibrary = PHPhotoLibrary.shared()
        try await photoLibrary.performChanges {
            let creationRequest = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            if #available(iOS 26.0, *),
                let contentType
            {
                options.contentType = contentType
            }

            // Could/should we insert the attribution (i.e. CC license + author) here?
            options.originalFilename = mediaFile.name

            creationRequest.addResource(with: .photo, data: data, options: options)
        }
    }
}
