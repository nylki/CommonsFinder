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
    var bookmarked: Date?

    init(
        lastViewed: Date? = nil,
        viewCount: UInt = 0,
        bookmarked: Date? = nil
    ) {
        self.lastViewed = lastViewed
        self.viewCount = viewCount
        self.bookmarked = bookmarked
    }

}

// MARK: - Database

/// See <https://github.com/groue/GRDB.swift/blob/master/README.md#records>
extension ItemInteraction: Codable, FetchableRecord, MutablePersistableRecord {
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let lastViewed = Column(CodingKeys.lastViewed)
        static let viewCount = Column(CodingKeys.viewCount)
        static let bookmarked = Column(CodingKeys.bookmarked)
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
