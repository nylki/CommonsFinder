//
//  WikimediaLanguage.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 23.11.24.
//

import Foundation

// http://www.wikidata.org/entity/Help:Wikimedia_language_codes/lists/all
// search API: https://commons.wikimedia.org/wiki/Special:ApiSandbox#action=languagesearch&format=json&search=b&formatversion=2
struct WikimediaLanguage: Hashable, Equatable, Identifiable, Sendable {
    let code: String

    /// The corresponding system Locale if applicable
    let locale: Locale?

    var id: String { code }

    // Returns either the name or if not available just the language-code as a fallback
    var localizedDescription: String {
        localizedName ?? code
    }

    var localizedName: String? {
        Locale.current.localizedString(forLanguageCode: code)
    }

    init(code: String) {
        self.code = code
        self.locale = .init(languageCode: .init(code))
    }

    init(code: String, locale: Locale) {
        self.code = code
        self.locale = locale
    }

    // these are just for testing and prototyping now: TODO: (we need a complete list later):
    static let all: [WikimediaLanguage] = [
        .init(code: "en"),
        .init(code: "de"),
        .init(code: "fr"),
        .init(code: "nl"),
    ]
}
