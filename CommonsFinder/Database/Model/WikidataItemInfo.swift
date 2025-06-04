//
//  WikidataItemInfo.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 04.06.25.
//

import Foundation
import GRDB

struct WikidataItemInfo: FetchableRecord, Equatable, Hashable, Decodable {
    var wikidataItem: WikidataItem
    var itemInteraction: ItemInteraction?
}

extension WikidataItemInfo: Identifiable {
    var id: String { wikidataItem.id }
}
