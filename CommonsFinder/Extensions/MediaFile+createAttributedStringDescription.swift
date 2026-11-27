//
//  MediaFile+attributedString.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 05.11.24.
//

import Foundation
import RegexBuilder
import SwiftSoup
import SwiftUI
import os.log

extension AttributedString {
    nonisolated static func parse(htmlOrString: String, font: Font = .body) -> AttributedString? {
        do {
            var attributedString = AttributedString()

            let allowList =
                try Whitelist
                .simpleText()
                .addTags("a", "div", "span", "href")
                .addAttributes("a", "href")
                .addAttributes("div", "style")
                .addCSSProperties("div", "display")


            guard let clean = try SwiftSoup.clean(htmlOrString, allowList) else {
                return nil
            }

            let document = try SwiftSoup.parseBodyFragment(clean)
            guard let body = document.body() else { return nil }

            for node in body.getChildNodes() {
                if let textNode = node as? TextNode {
                    // Raw text (without enclosing html tags)
                    let text = textNode.text()
                    let part = AttributedString(text)
                    attributedString.append(part)
                } else if let tag = node as? Element {


                    if let attributes = tag.getAttributes(),
                        attributes.get(key: "style").replacing(.whitespace, with: "").contains("display:none")
                    {
                        // dicard elements with "display:none"
                        continue
                    }
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
