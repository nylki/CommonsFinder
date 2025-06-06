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
