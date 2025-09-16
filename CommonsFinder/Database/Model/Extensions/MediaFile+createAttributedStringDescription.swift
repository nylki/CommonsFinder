//
//  MediaFile+attributedString.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 05.11.24.
//

import CommonsAPI
import Foundation
import SwiftUI
import os.log

extension MediaFile {
    // TODO: should this be cached?
    // FIXME: maybe explicitly also run off main thread if allowed for AttributedString
    nonisolated
        func createAttributedStringDescription(font: Font = .body, locale: Locale) -> AttributedString?
    {
        let preferredLanguage = locale.wikiLanguageCodeIdentifier
        let languageString = fullDescriptions.first { $0.languageCode == preferredLanguage } ?? fullDescriptions.first { $0.languageCode == "en" }
        guard let localizedDescription = languageString?.string else {
            return nil
        }
        // Treat fullDescription as html -> convert to AttributedString
        guard
            let nsAttributedString = try? NSAttributedString(
                data: Data(localizedDescription.utf8),
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: NSUTF8StringEncoding,
                ],
                documentAttributes: nil
            )
        else {
            return nil
        }

        var attributedString = AttributedString(nsAttributedString)
        attributedString.foregroundColor = .primary
        attributedString.font = font
        return attributedString
    }
}
