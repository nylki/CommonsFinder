//
//  ItemInteraction.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 04.10.24.
//

import Foundation
import GRDB

/// `ItemInteraction` stores interaction metada for MediaFile and WikidataItem
///  eg. `lastViewed` or `viewCount`, `isBookmarked`
struct ItemInteraction: Equatable, Hashable, Sendable {

    /// used for SQL relation to MediaFile
    var mediaFileId: String?
    /// used for SQL relation to WikidataItem
    var wikidataItemId: String?

    var lastViewed: Date?
    var viewCount: UInt
    var isBookmarked: Bool

    /// init for MediaFile
    init(
        mediaFileId: String,
        lastViewed: Date? = nil,
        viewCount: UInt = 0,
        isBookmarked: Bool = false
    ) {
        self.mediaFileId = mediaFileId
        self.lastViewed = lastViewed
        self.viewCount = viewCount
        self.isBookmarked = isBookmarked
    }

    /// init for WikidataItem
    init(
        wikidataItemId: String,
        lastViewed: Date? = nil,
        viewCount: UInt = 0,
        isBookmarked: Bool = false
    ) {
        self.wikidataItemId = wikidataItemId
        self.lastViewed = lastViewed
        self.viewCount = viewCount
        self.isBookmarked = isBookmarked
    }
}

extension ItemInteraction: Identifiable {
    var id: String {
        if mediaFileId == nil && wikidataItemId == nil {
            assertionFailure("Atleast one id must be present for this type to be valid!")

        }

        if mediaFileId != nil && wikidataItemId != nil {
            assertionFailure("Exactly one id must be present, but more ids are non-null!")
        }

        // Unsafe unwrapping is acceptable here
        return (mediaFileId ?? wikidataItemId)!
    }
}

// MARK: - Database

/// See <https://github.com/groue/GRDB.swift/blob/master/README.md#records>
extension ItemInteraction: Codable, FetchableRecord, MutablePersistableRecord {
    enum Columns {
        static let mediaFileId = Column(CodingKeys.mediaFileId)
        static let wikidataItemId = Column(CodingKeys.wikidataItemId)
        static let lastViewed = Column(CodingKeys.lastViewed)
        static let viewCount = Column(CodingKeys.viewCount)
        static let isBookmarked = Column(CodingKeys.isBookmarked)
    }

    static let mediaFile = belongsTo(MediaFile.self)
    static let wikidataItem = belongsTo(WikidataItem.self)

    var mediaFile: QueryInterfaceRequest<MediaFile> {
        request(for: ItemInteraction.mediaFile)
    }
    var wikidataItem: QueryInterfaceRequest<WikidataItem> {
        request(for: ItemInteraction.wikidataItem)
    }
}
