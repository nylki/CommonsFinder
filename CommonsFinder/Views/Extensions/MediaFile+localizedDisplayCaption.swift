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
        if let preferredCaption = captions.first(where: { $0.languageCode == Locale.current.wikiLanguageCodeIdentifier }) {
            return preferredCaption.string
        } else if let anyCaption = captions.first {
            return anyCaption.string
        } else {
            return nil
        }
    }
}
