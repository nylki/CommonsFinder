//
//  Category+Thumbnail.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 01.04.25.
//


import Foundation
import Nuke

extension Category {
    // see acceptable sizes: https://www.mediawiki.org/wiki/Common_thumbnail_sizes
    var thumbnailImage: Nuke.ImageRequest? {
        if let image,
            let resizedURL = try? URL.experimentalResizedCommonsImageURL(filename: image.lastPathComponent, maxWidth: 500)
        {
            Nuke.ImageRequest(url: resizedURL)
        } else {
            nil
        }
    }
}
