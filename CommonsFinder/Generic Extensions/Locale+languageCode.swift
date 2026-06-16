//
//  Locale+languageCode.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 04.02.25.
//

import Foundation

nonisolated extension Locale {
    var wikiLanguageCodeIdentifier: String {
        // TODO: check actual usage and maybe not default to "en"
        language.languageCode?.identifier ?? "en"
    }
}

nonisolated extension Locale.LanguageCode: @retroactive Identifiable {
    public var id: String { identifier }
}


nonisolated extension Locale.LanguageCode {
    var localizedLanguageName: String {
        Locale.current.localizedString(forLanguageCode: identifier) ?? identifier
    }
}


nonisolated extension Locale.LanguageCode {
    static var preferredLanguageCodes: [Self] {
        if #available(iOS 26, *) {
            Locale.preferredLocales.compactMap { locale in
                locale.language.languageCode ?? Self.languageCodeFromRegionLanguageCode(locale.identifier)
            }
        } else {
            Locale.preferredLanguages.compactMap(Self.languageCodeFromRegionLanguageCode)
        }
    }

    /// eg "de-CH" -> "de"
    private static func languageCodeFromRegionLanguageCode(_ string: String) -> Self? {
        let split = string.split(separator: "-")

        if !split.isEmpty {
            let code = String(split[0])
            return .init(code)
        } else {
            return nil
        }
    }
}
