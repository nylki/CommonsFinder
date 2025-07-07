//
//  CategoryInfo.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 04.06.25.
//

import Foundation
import GRDB

struct CategoryInfo: FetchableRecord, Equatable, Hashable, Codable {
    var base: Category
    var itemInteraction: ItemInteraction?

    var isBookmarked: Bool {
        itemInteraction?.isBookmarked ?? false
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

extension CategoryInfo: Identifiable {
    // NOTE: The base wikidataItem _must_ have atleast one of wikidataId or commonsCategory
    // as defined in the DB constraint (see database.swift), so it should always be safe to assume
    // that it is identifiable by one of them.
    // However we cannot make the base-item itself identifiable as that would be problematic for several reason
    // mainly not being sure if the item is already persisted with its auto-incremented id.
    // see: https://github.com/groue/GRDB.swift/issues/1435#issuecomment-1740857712).
    var id: String { (base.wikidataId ?? base.commonsCategory)! }
}

extension CategoryInfo {
    static func randomItem(id: String) -> Self {
        .init(.randomItem(id: id))
    }
}
