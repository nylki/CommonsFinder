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
    var thumbRequest: ImageRequest? {
        if let thumbURL = mediaFile.thumbURL {
            let imageResize = ImageProcessors.Resize(size: .init(width: 640, height: 640))
            let urlRequest = URLRequest(url: thumbURL, cachePolicy: .returnCacheDataElseLoad)
            return .init(urlRequest: urlRequest, processors: [imageResize])
        }
        return nil
    }

    // this is not the original image, but a resized one from the server, because some images
    // are huge (eg. tif + large dimensions), but we don't need that for an un-zoomed image
    var largeResizedRequest: ImageRequest? {
        let max = 1280
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

    var originalImageRequest: ImageRequest {
        let urlRequest = URLRequest(url: mediaFile.url, cachePolicy: .returnCacheDataElseLoad)
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
