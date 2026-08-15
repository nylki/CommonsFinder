//
//  File.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 31.05.25.
//

import CommonsAPI
import SwiftUI

extension MediaFile {
    /// the preferred caption depending on user locales, otherwise any caption.
    var localizedDisplayCaption: String? {
        if let preferredCaption {
            return preferredCaption.string
        } else if let anyCaption = captions.first {
            return anyCaption.string
        } else {
            return nil
        }
    }

    /// returns the localized version of the file full description, parsed as AttributedString
    /// values are cached.
    var attributedStringDescription: AttributedString? {
        let preferredLanguage = Locale.current.wikiLanguageCodeIdentifier
        let languageString = fullDescriptions.first { $0.languageCode == preferredLanguage } ?? fullDescriptions.first { $0.languageCode == "en" }
        guard let localizedDescription = languageString?.string else { return nil }

        return AttributedStringCache.shared[localizedDescription]
    }

    /// either returns the localized caption, the localized description as String (converted as plaintext from its AttributedString version) and if neither exists, the displayName is returned
    var bestShortTitle: String {
        return if let preferredCaption {
            preferredCaption.string
        } else if let description = attributedStringDescription?.characters {
            String(description)
        } else if let anyCaption = captions.first {
            anyCaption.string
        } else {
            displayName
        }
    }

    private var preferredCaption: LanguageString? {
        var caption: LanguageString? = captions.first(where: { $0.languageCode == Locale.current.wikiLanguageCodeIdentifier })

        if caption == nil, #available(iOS 26.0, *) {
            caption = captions.first(where: {
                Locale.preferredLocales.contains(.init(languageCode: .init($0.languageCode)))
            })
        }
        return caption
    }
}
