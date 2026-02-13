//
//  PublishHelpers.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 05.02.26.
//

import Algorithms
import CommonsAPI
import Foundation
import RegexBuilder

enum PublishHelpers {
    struct ParsedCategory {
        let name: String
        let normalized: String
        let raw: String
        let range: Range<String.Index>
    }

    private static let categoryNameRef = Reference(Substring.self)

    // Matches `[[Category:Name|sort key]]` and
    // captures only the category name before `|` or `]]` so we can preserve raw markup.
    private static let categoryRegex = Regex {
        "[["
        ZeroOrMore(.whitespace)
        "Category"
        ZeroOrMore(.whitespace)
        ":"
        ZeroOrMore(.whitespace)
        Capture(as: categoryNameRef) {
            OneOrMore {
                CharacterClass(.anyOf("]|").inverted)
            }
        }
        ZeroOrMore {
            CharacterClass(.anyOf("]").inverted)
        }
        "]]"
    }
    .ignoresCase()

    static func normalizedCategoryName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func parseCategories(from wikitext: String) -> [ParsedCategory] {
        wikitext.matches(of: categoryRegex)
            .compactMap { match in
                let raw = String(wikitext[match.range])
                let name = String(match[categoryNameRef]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return nil }
                return ParsedCategory(
                    name: name,
                    normalized: normalizedCategoryName(name),
                    raw: raw,
                    range: match.range
                )
            }
    }

    static func removingCategories(from wikitext: String) -> String {
        wikitext.replacing(categoryRegex, with: "")
    }

    static func selectedCategoryNames(from tags: [TagItem]) -> [String] {
        tags.compactMap { tag in
            guard tag.pickedUsages.contains(.category),
                let name = tag.baseItem.commonsCategory,
                !name.isEmpty
            else {
                return nil
            }
            return name
        }
    }

    static func selectedDepictItemIDs(from tags: [TagItem]) -> [WikidataItemID] {
        tags.compactMap { tag in
            guard tag.pickedUsages.contains(.depict) else { return nil }
            return tag.baseItem.wikidataItemID
        }
    }

    static func labelDiff(
        current: [LanguageString],
        target: [LanguageString]
    ) -> (set: [LanguageString], remove: [LanguageCode]) {
        guard current != target else {
            return (set: [], remove: [])
        }

        let currentLanguages = Set(current.map(\.languageCode))
        let targetLanguages = Set(target.map(\.languageCode))
        let removedLanguages = currentLanguages.subtracting(targetLanguages)
        let currentDict: [LanguageCode: LanguageString] = current.grouped(by: \.languageCode).compactMapValues { $0.first }

        let labelsToSet: [LanguageString] = target.filter {
            !removedLanguages.contains($0.languageCode) && $0.string != currentDict[$0.languageCode]?.string
        }

        return (set: labelsToSet, remove: Array(removedLanguages))
    }

    static func updateCategories(in wikitext: String, selectedCategories: [String], knownCategories: Set<String>) -> String {
        let parsedCategories = parseCategories(from: wikitext)
        let selectedNormalized = Set(selectedCategories.map(normalizedCategoryName))

        var existingNormalized = Set<String>()
        var keptNormalized = Set<String>()
        var output = ""
        var lastIndex = wikitext.startIndex

        for parsed in parsedCategories {
            existingNormalized.insert(parsed.normalized)
            output += String(wikitext[lastIndex..<parsed.range.lowerBound])

            let shouldKeep =
                selectedNormalized.contains(parsed.normalized)
                || !knownCategories.contains(parsed.normalized)

            if shouldKeep, keptNormalized.insert(parsed.normalized).inserted {
                output += parsed.raw
            }

            lastIndex = parsed.range.upperBound
        }

        output += String(wikitext[lastIndex..<wikitext.endIndex])


        var appendedLines = Set<String>()
        for category in selectedCategories {
            let normalized = normalizedCategoryName(category)
            guard appendedLines.insert(normalized).inserted else { continue }
            guard !existingNormalized.contains(normalized) else { continue }
            appendedLines.insert("[[Category:\(category)]]")
        }

        guard !appendedLines.isEmpty else {
            return output
        }

        var updatedText = output
        if !updatedText.hasSuffix("\n") {
            updatedText += "\n"
        }
        updatedText += appendedLines.joined(separator: "\n")
        if !updatedText.hasSuffix("\n") {
            updatedText += "\n"
        }
        return updatedText
    }

    static func categoryEditSummary(
        selectedCategories: [String],
        referenceCategories: [String],
        maxLength: Int = 240
    ) -> String {

        let toolName = Networking.shared.editAndUploadCommentSuffix

        let selectedByNormalized = Dictionary(
            selectedCategories.map { (normalizedCategoryName($0), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let referenceByNormalized = Dictionary(
            referenceCategories.map { (normalizedCategoryName($0), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let selectedSet = Set(selectedByNormalized.keys)
        let referenceSet = Set(referenceByNormalized.keys)

        let added = selectedSet.subtracting(referenceSet).sorted()
        let removed = referenceSet.subtracting(selectedSet).sorted()

        var parts: [String] = []
        parts.append(
            contentsOf: added.compactMap { normalized in
                guard let name = selectedByNormalized[normalized] else { return nil }
                return "+[[Category:\(name)]]"
            })
        parts.append(
            contentsOf: removed.compactMap { normalized in
                guard let name = referenceByNormalized[normalized] else { return nil }
                return "-[[Category:\(name)]]"
            })

        let joined = parts.joined(separator: "; ")
        let summary =
            joined.isEmpty
            ? "Updated categories with \(toolName)"
            : "\(joined) (edited with \(toolName))"

        if summary.count <= maxLength {
            return summary
        }

        var fallbackParts: [String] = []
        if !added.isEmpty { fallbackParts.append("+\(added.count) category") }
        if !removed.isEmpty { fallbackParts.append("-\(removed.count) category") }
        let fallbackJoined = fallbackParts.joined(separator: ", ")
        return fallbackJoined.isEmpty
            ? "Updated categories with \(toolName)"
            : "\(fallbackJoined) (edited with \(toolName))"
    }
}
