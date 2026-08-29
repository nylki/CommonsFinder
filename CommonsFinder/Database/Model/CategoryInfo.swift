//
//  CategoryInfo.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 04.06.25.
//

import Foundation
import GRDB

nonisolated struct CategoryInfo: FetchableRecord, Equatable, Hashable, Codable {
    var base: Category
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

    init(_ base: Category, itemInteraction: ItemInteraction? = nil) {
        self.base = base
        self.itemInteraction = itemInteraction
    }
}

nonisolated extension CategoryInfo: Identifiable {
    var id: String { base.composedID }
}

extension CategoryInfo {
    static func randomItem(id: String) -> Self {
        .init(.randomItem(id: id))
    }
}
