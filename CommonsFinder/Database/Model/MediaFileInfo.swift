//
//  MediaFileInfo.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 24.01.25.
//

import Foundation
import GRDB

struct MediaFileInfo: FetchableRecord, Equatable, Hashable, Decodable {
    var mediaFile: MediaFile
    var itemInteraction: ItemInteraction?

    var isBookmarked: Bool {
        itemInteraction?.bookmarked != nil
    }

    var bookmarkDate: Date? {
        itemInteraction?.bookmarked
    }

    var viewCount: UInt {
        itemInteraction?.viewCount ?? 0
    }

    var lastViewed: Date? {
        itemInteraction?.lastViewed
    }

    init(mediaFile: MediaFile, itemInteraction: ItemInteraction? = nil) {
        self.mediaFile = mediaFile
        self.itemInteraction = itemInteraction
    }
}

extension MediaFileInfo: Identifiable {
    var id: String { mediaFile.id }
}

extension MediaFileInfo {
    static func makeRandomUploaded(id: MediaFile.ID, _ imageType: TestImageType) -> MediaFileInfo {
        let mediaFile = MediaFile.makeRandomUploaded(id: id, imageType)
        return .init(mediaFile: mediaFile, itemInteraction: nil)
    }
}
