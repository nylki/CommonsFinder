//
//  WikidataItem+Thumbnail.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 01.04.25.
//


import Foundation
import Nuke

extension WikidataItem {
    var thumbnailImage: Nuke.ImageRequest? {
        if let image,
            let resizedURL = try? URL.experimentalResizedCommonsImageURL(filename: image.lastPathComponent, maxWidth: 640)
        {
            Nuke.ImageRequest(url: resizedURL)
        } else {
            nil
        }
    }
}
