//
//  DraftSource.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.03.26.
//

import Foundation
import CommonsAPI

nonisolated enum DraftSource: Codable, Equatable, Hashable {
        // see: https://commons.wikimedia.org/wiki/Commons:Structured_data/Modeling/Source
        // "Wikidata: *\(id)*"P7482

        case own
        case fileFromTheWeb(URL)
        // TODO: check correct modelling
        case book(WikidataItemID, page: Int)
}
