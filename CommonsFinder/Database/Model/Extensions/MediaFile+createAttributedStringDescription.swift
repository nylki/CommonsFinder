//
//  MediaFile+attributedString.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 05.11.24.
//

import CommonsAPI
import Foundation
import SwiftSoup
import SwiftUI
import os.log

extension AttributedString {

    init(htmlOrString: String) async {
        self.init()
        self = await Self.parse(htmlOrString: htmlOrString) ?? .init()
    }

    @concurrent static private func parse(htmlOrString: String, font: Font = .body) async -> AttributedString? {
        do {
            var attributedString = AttributedString()

            let allowList =
                try Whitelist
                .simpleText()
                .addTags("a", "div", "span", "href")
                .addAttributes("a", "href")

            guard let clean = try SwiftSoup.clean(htmlOrString, allowList) else {
                return nil
            }

            let document: Document = try SwiftSoup.parseBodyFragment(clean)
            guard let body = document.body() else { return nil }

            for node in body.getChildNodes() {
                if let textNode = node as? TextNode {
                    // Raw text (without enclosing html tags)
                    let text = textNode.text()
                    let part = AttributedString(text)
                    attributedString.append(part)
                } else if let tag = node as? Element {
                    let text = try tag.text()
                    var part = AttributedString(text)

                    if try tag.iS("a"),
                        let urlString = try? tag.attr("href"),
                        let url = URL(string: urlString)
                    {
                        part.link = url
                        part.underlineStyle = .single
                    }

                    attributedString.append(part)
                }
            }

            attributedString.foregroundColor = .primary

            return attributedString
        } catch {
            return nil
        }
    }
}

extension MediaFile {
    /// returns the localized version of the file full description, parsed as AttributedString
    /// values are cached.
    var attributedStringDescription: AttributedString? {
        let preferredLanguage = Locale.current.wikiLanguageCodeIdentifier
        let languageString = fullDescriptions.first { $0.languageCode == preferredLanguage } ?? fullDescriptions.first { $0.languageCode == "en" }
        guard let localizedDescription = languageString?.string else { return nil }

        return AttributedStringCache.shared[localizedDescription]
    }
}
