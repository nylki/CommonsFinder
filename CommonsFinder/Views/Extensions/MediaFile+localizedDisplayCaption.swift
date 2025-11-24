//
//  File.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 31.05.25.
//

import CommonsAPI
import SwiftUI

extension MediaFile {
    var localizedDisplayCaption: String? {
        if let preferredCaption {
            return preferredCaption.string
        } else if let anyCaption = captions.first {
            return anyCaption.string
        } else {
            return nil
        }
    }

    /// either returns the localized caption, the localized description as String (converted as plaintext from its AttributedString version) and if neither exists, the displayName wis returned
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
