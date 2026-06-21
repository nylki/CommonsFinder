//
//  WikimediaLanguage.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 17.06.26.
//

import Foundation

struct WikimediaLanguage: Sendable, Hashable, Equatable, Codable, CustomStringConvertible {
    let code: String
    /// the name if the language in its own language
    let autonym: String?
    /// this is a localized name
    let name: String?

    var description: String {
        name ?? autonym ?? code
    }
}

extension WikimediaLanguage: Identifiable {
    var id: String { code }
}
