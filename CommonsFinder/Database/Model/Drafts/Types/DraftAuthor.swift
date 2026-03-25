//
//  DraftAuthor.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.03.26.
//

import Foundation
import CommonsAPI

nonisolated enum DraftAuthor: Codable, Equatable, Hashable {
        case appUser
        case custom(name: String, wikimediaUsername: String?, url: URL?)
        case wikidataId(wikidataItem: WikidataItemID)
}


