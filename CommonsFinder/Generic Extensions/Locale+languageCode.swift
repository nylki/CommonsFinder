//
//  Locale+languageCode.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 04.02.25.
//

import Foundation

nonisolated extension Locale {
    var wikiLanguageCodeIdentifier: String {
        language.languageCode?.identifier ?? "en"
    }
}
