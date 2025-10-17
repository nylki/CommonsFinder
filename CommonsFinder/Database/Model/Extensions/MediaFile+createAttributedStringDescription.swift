//
//  MediaFile+attributedString.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 05.11.24.
//

import CommonsAPI
import Foundation
import LRUCache
import SwiftSoup
import SwiftUI
import os.log

extension AttributedString {
    static private let cache = LRUCache<String, AttributedString>(countLimit: 250)

    init(htmlOrString: String) async {
        self.init()
        if let cachedAttributedString = Self.cache.value(forKey: htmlOrString) {
            //            logger.info("P: cache hit")
            self = cachedAttributedString
        } else {
            //            logger.info("P: no cache hit")
            let attributedString = await Self.parse(htmlOrString: htmlOrString) ?? .init()
            Self.cache.setValue(attributedString, forKey: htmlOrString)
            self = attributedString
        }
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
    nonisolated func createAttributedStringDescription(font: Font = .body, locale: Locale) async -> AttributedString? {

        //        let signposter = OSSignposter()
        //        let signpostID = signposter.makeSignpostID()
        //        let signPostName: StaticString = "createAttributedStringDescription"
        //        let state = signposter.beginInterval(signPostName, id: signpostID)
        //        defer {
        //            signposter.endInterval(signPostName, state)
        //        }

        let preferredLanguage = locale.wikiLanguageCodeIdentifier
        let languageString = fullDescriptions.first { $0.languageCode == preferredLanguage } ?? fullDescriptions.first { $0.languageCode == "en" }
        guard let localizedDescription = languageString?.string else {
            return nil
        }

        var attributedString = await AttributedString(htmlOrString: localizedDescription)
        attributedString.font = font
        return attributedString
    }
}
