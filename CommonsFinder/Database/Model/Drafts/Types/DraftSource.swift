//
//  DraftSource.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.03.26.
//

import CommonsAPI
import Foundation

nonisolated enum DraftSource: Codable, Equatable, Hashable {
    // see: https://commons.wikimedia.org/wiki/Commons:Structured_data/Modeling/Source
    // "Wikidata: *\(id)*"P7482

    case own
    /// more specific version than just `own`, especially useful for photographs of paintings, or other artworks
    case selfPhotographed
    case otherSource(String)

    var url: URL? {
        switch self {
        case .own, .selfPhotographed:
            nil
        case .otherSource(let string):
            if string.starts(with: "http"), let url = URL(string: string) {
                url
            } else {
                nil
            }
        }
    }
}
