//
//  ItemInteraction.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 04.10.24.
//

import Foundation
import GRDB

/// `ItemInteraction` stores interaction metada for MediaFile and Category
///  eg. `lastViewed` or `viewCount`, `isBookmarked`
struct ItemInteraction: Equatable, Hashable, Sendable, Identifiable {
    var id: Int64?

    var lastViewed: Date?
    var viewCount: UInt
    var isBookmarked: Bool
    //    var bookmarkDate: Date?

    init(
        lastViewed: Date? = nil,
        viewCount: UInt = 0,
        isBookmarked: Bool = false
    ) {
        self.lastViewed = lastViewed
        self.viewCount = viewCount
        self.isBookmarked = isBookmarked
    }

}

// MARK: - Database

/// See <https://github.com/groue/GRDB.swift/blob/master/README.md#records>
extension ItemInteraction: Codable, FetchableRecord, MutablePersistableRecord {
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let lastViewed = Column(CodingKeys.lastViewed)
        static let viewCount = Column(CodingKeys.viewCount)
        static let isBookmarked = Column(CodingKeys.isBookmarked)
    }

    /// Updates the id after it has been inserted in the database.
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    static let wikidataItem = hasOne(Category.self)
    static let mediaFile = hasOne(MediaFile.self)

    var wikidataItem: QueryInterfaceRequest<Category> {
        request(for: ItemInteraction.wikidataItem)
    }
    var mediaFile: QueryInterfaceRequest<MediaFile> {
        request(for: ItemInteraction.mediaFile)
    }
}
