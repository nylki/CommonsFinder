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
    @concurrent
    func createAttributedStringDescription(font: Font = .body, locale: Locale) async -> AttributedString? {
        // NOTE: This function is expensive as it may block the main actor (does it really or jsut side-effect of layout changes), check performance regularily in Release builds scrolling long lists of media preview in Categories and potentially see if this can be optimized.
        logger.debug("calling createAttributedStringDescription")

        let preferredLanguage = locale.wikiLanguageCodeIdentifier
        let languageString = fullDescriptions.first { $0.languageCode == preferredLanguage } ?? fullDescriptions.first { $0.languageCode == "en" }
        guard let localizedDescription = languageString?.string else {
            return nil
        }
        // HACKY: to offload the potentially blocking work when this func is called multiple times
        // in different places, temporally spread out the work somewhat randomly
        try? await Task.sleep(for: .milliseconds(Int.random(in: 1...75)))
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

        attributedString.backgroundColor = .clear
        attributedString.font = font
        attributedString.foregroundColor = .primary

        return attributedString
    }
}
