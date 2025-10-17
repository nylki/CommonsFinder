//
//  MediaFile+ImageRequest.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 29.10.24.
//

import CoreGraphics
import Foundation
import Nuke

extension MediaFileInfo {
    private static var imageImageTypesIgnoredForDirectRenderingInThumbnails = ["svg", "video", "mp4", "pdf", "ogv", "mpeg"]

    private var isMimeTypeCompatibleForDirectRenderingInThumbnails: Bool {
        if let mimeType = mediaFile.mimeType {
            Self.imageImageTypesIgnoredForDirectRenderingInThumbnails.allSatisfy {
                !mimeType.contains($0)
            }
        } else {
            false
        }

    }

    var thumbRequest: ImageRequest? {
        let max = 640

        // shortcut to original image if that is smaller or same size as the thumb
        // this improves cachability, eg. when requesting the original in a zoom viewer.
        if let width = mediaFile.width, let height = mediaFile.height,
            width <= max,
            height <= max,
            isMimeTypeCompatibleForDirectRenderingInThumbnails
        {
            return originalImageRequest()
        }

        if let thumbURL = mediaFile.thumbURL {
            let imageResize = ImageProcessors.Resize(size: .init(width: max, height: max))
            let urlRequest = URLRequest(url: thumbURL, cachePolicy: .returnCacheDataElseLoad)
            return .init(urlRequest: urlRequest, processors: [imageResize])
        }
        return nil
    }

    // this is not the original image, but a resized one from the server, because some images
    // are huge (eg. tif + large dimensions), but we don't need that for an un-zoomed image
    var largeResizedRequest: ImageRequest? {
        let max = 1280

        // shortcut to original image if that is smaller or same size as the thumb
        // this improves cachability, eg. when requesting the original in a zoom viewer.
        if let width = mediaFile.width, let height = mediaFile.height,
            width <= max,
            height <= max,
            isMimeTypeCompatibleForDirectRenderingInThumbnails
        {
            return originalImageRequest()
        }

        let w = min(max, mediaFile.width ?? max)
        if let resizedURL = try? mediaFile.url.resizedCommonsImageURL(maxWidth: w) {
            let imageResize = ImageProcessors.Resize(size: .init(width: w, height: w))
            let urlRequest = URLRequest(url: resizedURL, cachePolicy: .returnCacheDataElseLoad)
            return .init(urlRequest: urlRequest, processors: [imageResize])
        }
        return nil
    }

    /// this is an alternative version to the original image if that is too big (dimensions or filesize) to render
    var maxResizedRequest: ImageRequest? {
        let max = ViewConstants.maxFullscreenLengthPx
        let w = min(max, mediaFile.width ?? max)
        if let resizedURL = try? mediaFile.url.resizedCommonsImageURL(maxWidth: w) {
            let imageResize = ImageProcessors.Resize(size: .init(width: w, height: w))
            let urlRequest = URLRequest(url: resizedURL, cachePolicy: .returnCacheDataElseLoad)
            return .init(urlRequest: urlRequest, processors: [imageResize])
        }
        return nil
    }

    func originalImageRequest(cachePolicy: URLRequest.CachePolicy = .returnCacheDataElseLoad) -> ImageRequest {
        let urlRequest = URLRequest(url: mediaFile.url, cachePolicy: cachePolicy)
        return .init(urlRequest: urlRequest, processors: [])
    }
}

extension MediaFileDraft {
    var localFileRequestFull: ImageRequest? {
        if let fileURL = localFileURL() {
            return .init(url: fileURL, processors: [])
        }
        return nil
    }

    var localFileRequestResized: ImageRequest? {
        if let fileURL = localFileURL() {
            let imageResize = ImageProcessors.Resize(size: .init(width: 640, height: 640))
            return .init(url: fileURL, processors: [imageResize])
        }
        return nil
    }
}
