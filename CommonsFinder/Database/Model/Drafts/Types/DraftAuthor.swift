//
//  DraftAuthor.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.03.26.
//

import CommonsAPI
import Foundation

nonisolated enum DraftAuthor: Codable, Equatable, Hashable {
    case appUser
    case custom(author: CustomAuthor)
    case wikidataId(wikidataItem: WikidataItemID)
    case unknown

    var customAuthor: CustomAuthor? {
        get {
            switch self {
            case .appUser:
                nil
            case .custom(let author):
                author
            case .wikidataId(let wikidataItem):
                nil
            case .unknown:
                nil
            }
        }
        set {
            if let newValue {
                self = .custom(author: newValue)
            }
        }
    }

    struct CustomAuthor: Codable, Equatable, Hashable {
        var name: String
        var wikimediaUsername: String?
        var url: URL?
    }
}
