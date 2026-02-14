//
//  PublishHelpersTests.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 05.02.26.
//

import CommonsAPI
import Foundation
import Testing

@Suite("Publish Helpers")
struct PublishHelpersTests {

    private func labels(_ pairs: [(String, String)]) -> [LanguageString] {
        pairs.map { .init($0.0, languageCode: $0.1) }
    }

    @Test("Category regex captures names and raw markup")
    func categoryRegexCapturesNamesAndRaw() {
        let wikitext = """
            Intro
            [[Category:Foo]]
            [[Category:Foobar_something]]
            Middle [[category : Bar|Sort Key]] Lorel Ipsum Dolor Sitit
            [[Category:Blub|B]]
            Outro
            """

        let parsed = PublishHelpers.parseCategories(from: wikitext)
        #expect(parsed.count == 4)
        #expect(parsed[0].name == "Foo")
        #expect(parsed[0].raw == "[[Category:Foo]]")
        #expect(parsed[1].name == "Foobar_something")
        #expect(parsed[1].raw == "[[Category:Foobar_something]]")
        #expect(parsed[2].name == "Bar")
        #expect(parsed[2].raw == "[[category : Bar|Sort Key]]")
        #expect(parsed[3].name == "Blub")
        #expect(parsed[3].raw == "[[Category:Blub|B]]")
    }

    @Test("Removing categories strips markup anywhere in text")
    func removingCategoriesStripsAnywhere() {
        let wikitext = """
            Text at the top. [[Category:One]]
            Lorem ipsum dolor sit amet.
            [[Category:Two|x]]
            Some unusual text at the end.
            """

        let expected = """
            Text at the top. 
            Lorem ipsum dolor sit amet.

            Some unusual text at the end.
            """
        let cleaned = PublishHelpers.removingCategories(from: wikitext)
        #expect(!cleaned.contains("[[Category:"))
        #expect(!cleaned.contains("[[category:"))
        #expect(cleaned == expected)
    }

    @Test("Update categories preserves existing positions and appends new ones")
    func updateCategoriesPreservesExistingPositionsAndAppendsNew() {
        let wikitext = """
            [[Category:Keep]]
            Intro text.
            Middle [[Category:RemoveMe]] sentence.
            [[Category:Sorted|Z]]
            Footer
            """

        let selected = ["AddMe", "Sorted"]
        let known: Set<String> = ["removeme", "sorted"]

        let updatedWikitext = PublishHelpers.updateCategories(in: wikitext, selectedCategories: selected, knownCategories: known)

        #expect(updatedWikitext.contains("[[Category:Keep]]"))
        #expect(updatedWikitext.contains("[[Category:Sorted|Z]]"))
        #expect(updatedWikitext.contains("[[Category:AddMe]]"))
        #expect(!updatedWikitext.contains("[[Category:RemoveMe]]"))

        guard let footerRange = updatedWikitext.range(of: "Footer") else {
            Issue.record("Updated text should contain footer.")
            return
        }

        for category in ["[[Category:Keep]]", "[[Category:Sorted|Z]]"] {
            let count = updatedWikitext.components(separatedBy: category).count - 1
            #expect(count == 1)
        }

        guard let addRange = updatedWikitext.range(of: "[[Category:AddMe]]") else {
            Issue.record("Expected category not found: [[Category:AddMe]]")
            return
        }
        #expect(addRange.lowerBound > footerRange.upperBound)
    }

    @Test("Update categories preserves raw sort key for selected category")
    func updateCategoriesPreservesSortKey() {
        let wikitext = """
            Text
            [[Category:Sorted|Z]]
            """
        let updated = PublishHelpers.updateCategories(
            in: wikitext,
            selectedCategories: ["Sorted"],
            knownCategories: ["sorted"]
        )

        #expect(updated.contains("[[Category:Sorted|Z]]"))
    }

    @Test("Selected tag helpers return categories and depicts")
    func selectedCategoryAndDepictsFromTags() {
        let categoryOnly = TagItem(.init(commonsCategory: "Cats"), pickedUsages: [.category])
        let depictOnly = TagItem(.init(wikidataId: "Q42"), pickedUsages: [.depict])
        let both = TagItem(.init(wikidataId: "Q2", commonsCategory: "Earth"), pickedUsages: [.category, .depict])
        let none = TagItem(.init(commonsCategory: "Ignored"), pickedUsages: [])

        let tags = [categoryOnly, depictOnly, both, none]

        let categories = Set(PublishHelpers.selectedCategoryNames(from: tags))
        #expect(categories == ["Cats", "Earth"])

        let depicts = Set(PublishHelpers.selectedDepictItemIDs(from: tags).map(\.id))
        #expect(depicts == ["Q42", "Q2"])
    }

    @Test("Label diff with empty target removes all current")
    func labelDiffEmptyTarget() {
        let current = labels([("Hello", "en"), ("Hallo", "de")])
        let diff = PublishHelpers.labelDiff(current: current, target: [])
        #expect(diff.set.isEmpty)
        #expect(Set(diff.remove) == ["en", "de"])
    }

    @Test("Label diff with empty current adds all target")
    func labelDiffEmptyCurrent() {
        let target = labels([("Hello", "en"), ("Bonjour", "fr")])
        let diff = PublishHelpers.labelDiff(current: [], target: target)
        #expect(Set(diff.set) == Set(target))
        #expect(diff.remove.isEmpty)
    }

    @Test("Label diff with added and removed and updated")
    func labelDiffAddedRemovedUpdated() {
        let current = labels([("Hello", "en"), ("Hallo", "de")])
        let target = labels([("Hello there", "en"), ("Bonjour", "fr")])
        let diff = PublishHelpers.labelDiff(current: current, target: target)
        #expect(Set(diff.set) == Set(target))
        #expect(Set(diff.remove) == ["de"])
    }

    @Test("Label diff with only added")
    func labelDiffOnlyAdded() {
        let current = labels([("Hello", "en")])
        let target = labels([("Hello", "en"), ("Bonjour", "fr")])
        let diff = PublishHelpers.labelDiff(current: current, target: target)
        #expect(diff.set == [target[1]])
        #expect(diff.remove.isEmpty)
    }

    @Test("Label diff with only removed")
    func labelDiffOnlyRemoved() {
        let current = labels([("Hello", "en"), ("Bonjour", "fr")])
        let target = labels([("Hello", "en")])
        let diff = PublishHelpers.labelDiff(current: current, target: target)
        #expect(diff.set.isEmpty)
        #expect(Set(diff.remove) == ["fr"])
    }

    @Test("Label diff with no changes")
    func labelDiffNoChanges() {
        let current = labels([("Hello", "en"), ("Bonjour", "fr")])
        let target = labels([("Hello", "en"), ("Bonjour", "fr")])
        let diff = PublishHelpers.labelDiff(current: current, target: target)
        #expect(diff.set.isEmpty)
        #expect(diff.remove.isEmpty)
    }

    @Test("Label diff with empty input")
    func labelDiffEmptyInput() {
        let diff = PublishHelpers.labelDiff(current: [], target: [])
        #expect(diff.set.isEmpty)
        #expect(diff.remove.isEmpty)
    }

    @Test("Label diff ignores ordering differences")
    func labelDiffIgnoresOrderingDifferences() {
        let current = labels([("Hello", "en"), ("Bonjour", "fr")])
        let target = labels([("Bonjour", "fr"), ("Hello", "en")])
        let diff = PublishHelpers.labelDiff(current: current, target: target)
        #expect(diff.set.isEmpty)
        #expect(diff.remove.isEmpty)
    }
}
