//
//  MediaFile+ImageRequest.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 29.10.24.
//

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
        // !!!!! CHECK METADATA SIZE AS BOUNDS!!!
        if let thumbURL = try? mediaFile.url.resizedCommonsImageURL(maxWidth: 1280) {
            let imageResize = ImageProcessors.Resize(size: .init(width: 1280, height: 1280))
            let urlRequest = URLRequest(url: thumbURL, cachePolicy: .returnCacheDataElseLoad)
            return .init(urlRequest: urlRequest, processors: [imageResize])
        }
        return nil
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
