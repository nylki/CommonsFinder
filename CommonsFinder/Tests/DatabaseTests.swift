//
//  DatabaseTests.swift
//  CommonsFinderTests
//
//  Created by Tom Brewe on 04.10.24.
//

import CommonsAPI
import Foundation
import GRDB
import Testing

@Suite("Database Tests")
struct DatabaseTests {

    nonisolated static var fileA: MediaFile {
        MediaFile(
            id: UUID().uuidString,
            name: "test title",
            url: .init(string: "https://upload.wikimedia.org/wikipedia/commons/testimage.jpg")!,
            descriptionURL: .init(string: "https://upload.wikimedia.org/wikipedia/commons/testimage.jpg")!,
            thumbURL: nil,
            uploadDate: .init(timeIntervalSince1970: 3600 * 12345),
            caption: [.init("test caption without any latin-you-know-which-words to test search", languageCode: "en")],
            fullDescription: [.init("Full description Lorem Ipsum Dolor sitit", languageCode: "en")],
            rawAttribution: nil,
            categories: ["Sample Image 2024", "Random Image", "Developer Test"],
            statements: [.depicts(.universe)],
            mimeType: "image/jpeg",
            username: "DBTester",
            fetchDate: Date.distantPast
        )
    }

    nonisolated static var fileB: MediaFile {
        MediaFile(
            id: UUID().uuidString,
            name: "test title",
            url: .init(string: "https://upload.wikimedia.org/wikipedia/commons/testimage2.jpg")!,
            descriptionURL: .init(string: "https://upload.wikimedia.org/wikipedia/commons/testimage2.jpg")!,
            thumbURL: nil,
            uploadDate: .init(timeIntervalSince1970: 3600 * 54323),
            caption: [],
            fullDescription: [],
            rawAttribution: "Some custom license",
            categories: ["Sample Image 2024", "Random Image", "Developer Test"],
            statements: [.depicts(.universe), .depicts(.earth), .dataSize(12_345_678)],
            mimeType: "image/jpeg",
            username: "DBTester",
            fetchDate: Date.distantPast
        )
    }

    @Test(
        "MediaFile insert and delete",
        arguments: [
            fileA,
            fileB,
            .makeRandomUploaded(id: UUID().uuidString, .horizontalImage),
            .makeRandomUploaded(id: UUID().uuidString, .squareImage),
            .makeRandomUploaded(id: UUID().uuidString, .verticalImage),
        ])
    func mediaFileInsert(_ mediaFile: MediaFile) async throws {
        // Given a properly configured and empty in-memory repo
        let dbQueue = try DatabaseQueue(configuration: AppDatabase.makeConfiguration())
        let repo = try AppDatabase(dbQueue)

        // When we insert an image model
        let insertedItem = try repo.insert(mediaFile)

        // Then the inserted MediaFile has the defined id
        #expect(insertedItem.name == mediaFile.name)

        // Then the inserted player exists in the database
        let fetchedMediaFile = try await repo.reader.read { db in
            try MediaFile.fetchOne(db, id: insertedItem.id)
        }
        #expect(fetchedMediaFile == insertedItem)

        // Fetching the annotated MediaFileInfo should also work and have a correct MediaFile
        // included.
        let fetchedMediaFileInfo = try repo.fetchMediaFileInfo(id: insertedItem.id)
        #expect(fetchedMediaFileInfo?.mediaFile == insertedItem)

        let wasDeleted = try repo.delete(insertedItem)
        #expect(wasDeleted)
    }

    @Test("Full-Text-Search (FTS5)")
    func fullTextSearch() async throws {
        let dbQueue = try DatabaseQueue(configuration: AppDatabase.makeConfiguration())
        let repo = try AppDatabase(dbQueue)

        let loremItem = MediaFile(
            id: UUID().uuidString,
            name: "test title",
            url: .init(string: "https://upload.wikimedia.org/wikipedia/commons/testimage.jpg")!,
            descriptionURL: .init(string: "https://upload.wikimedia.org/wikipedia/commons/testimage.jpg")!,
            thumbURL: nil,
            uploadDate: .init(timeIntervalSince1970: 3600 * 12345),
            caption: [.init("test caption without any latin-you-know-which-words to test search", languageCode: "en")],
            fullDescription: [.init("Full description Lorem Ipsum Dolor sitit", languageCode: "en")],
            rawAttribution: nil,
            categories: ["Sample Image 2024", "Random Image", "Developer Test"],
            statements: [.depicts(.universe)],
            mimeType: "image/jpeg",
            username: "DBTester",
            fetchDate: Date.distantPast
        )

        let germanItem = MediaFile(
            id: UUID().uuidString,
            name: "Test Datei",
            url: .init(string: "https://upload.wikimedia.org/wikipedia/commons/testimage.jpg")!,
            descriptionURL: .init(string: "https://upload.wikimedia.org/wikipedia/commons/testimage.jpg")!,
            thumbURL: nil,
            uploadDate: .init(timeIntervalSince1970: 3600 * 54321),
            caption: [.init("Hier testen wir eine andere Sprache mit Umlauten", languageCode: "de")],
            fullDescription: [.init("Überlange Beschreibungen kommen überall vor", languageCode: "de")],
            rawAttribution: nil,
            categories: ["Straßenzüge", "Zufallsbild"],
            statements: [.depicts(.universe)],
            mimeType: "image/jpeg",
            username: "DBTester",
            fetchDate: Date.distantPast
        )

        let insertedItems = try repo.upsert([loremItem, germanItem])
        #expect(insertedItems == [loremItem, germanItem])


        // Test Lorem Ipsum phrase
        var fetchedItems = try repo.fetchAllFiles(matchingPhrase: "Lore ip")
        #expect(fetchedItems.count == 1)
        #expect(
            fetchedItems.first == loremItem,
            "We expect to find loremItem because it has \"Lorem Ipsum\" in its `fullDescripion`"
        )

        // Test non-matching phrase
        fetchedItems = try repo.fetchAllFiles(matchingPhrase: "xyz")
        #expect(fetchedItems.isEmpty, "We dont expect to find items with this phrase")

        // Test german phrase matching something in categories array
        // NOTE: This test only works when the custom FTS5 Tokenizer
        fetchedItems = try repo.fetchAllFiles(matchingPhrase: "strasse")
        #expect(fetchedItems.count == 1)
        #expect(
            fetchedItems.first == germanItem,
            "We expect to find germanItem because it has \"Straßenzüge\" in one if its `categories`"
        )
    }

    @Test(
        "MediaFileDraft insert",
        arguments: [
            MediaFileDraft.makeRandomDraft(id: "test draft", named: "Test draft \(Int.random(in: 1..<99999))", date: .init(timeIntervalSince1970: 3600 * 12345))
        ])
    func mediaFileDraftInsert(_ draft: MediaFileDraft) async throws {
        // Given a properly configured and empty in-memory repo
        let dbQueue = try DatabaseQueue(configuration: AppDatabase.makeConfiguration())
        let repo = try AppDatabase(dbQueue)

        // When we insert an image model
        let inserted = try repo.upsertAndFetch(draft)

        // Then the inserted player has the defined id
        #expect(inserted.name == draft.name)

        // Then the inserted player exists in the database
        let fetchedItem = try await repo.reader.read { db in
            try MediaFileDraft.fetchOne(db)
        }

        #expect(fetchedItem != nil)
        #expect(fetchedItem == inserted)
    }

    @Test("Category upsert and delete", arguments: [Category.earth, .earthExtraLongLabel, .testItemNoDesc, .testItemNoLabel])
    func testCategoryUpsertAndDelete(_ category: Category) async throws {
        try #require(category.id == nil, "We require categories that do not come from the DB yet, ie. freshly network fetched.")
        let dbQueue = try DatabaseQueue(configuration: AppDatabase.makeConfiguration())
        let repo = try AppDatabase(dbQueue)

        let inserted = try #require(
            try repo.upsert(category),
            "We expect to get a category back after inserting."
        )

        #expect(inserted.id != nil)
        // Testing a selection of the most important arguments
        #expect(category.commonsCategory == inserted.commonsCategory)
        #expect(category.wikidataId == inserted.wikidataId)
        #expect(category.label == inserted.label)
        #expect(category.description == inserted.description)
        #expect(category.latitude == inserted.latitude)
        #expect(category.longitude == inserted.longitude)
        // NOTE: date tests when initialized with .now are for some reason unreliable
        // with Swift testing.

        let wasDeleted = try repo.delete(inserted)
        #expect(wasDeleted)
    }

    @Test(
        "Category upsert with conflict resolution, due to uniqueness constraints on `wikidataId` and `commonsCategory`",
        arguments: [
            // Consider the following possible scenario:
            // A. At commons.wikimedia.org, the category "Earth" exists (catA)
            // B. At wikidata.org, the item "Q1" (with label "The Earth") exists (catB).
            //    However, catB has no connection to catA yet (no "commonsCategory" linked in wikidata item).
            // C. the user views and interactions with A and B individually, creating two different entries in the appDatabase and corresponding views.
            // D. In the future, wikidata.org is updated, so that category "Earth" is finally linked in Q1.
            //    When the user would now fetch for either A or B, a combined item from wikidata would be returned.
            //    However the app already has two different entries and must now merge the new info with
            //    the interaction data (bookmarks, etc.) of both A and B.
            (
                // A:
                Category(commonsCategory: "Earth"),
                // B:
                Category(wikidataId: "Q1", label: "The Earth"),
                // C:
                Category(wikidataId: "Q1", commonsCategory: "Earth")
            )
        ])
    func testConflictingUpsert(catA: Category, catB: Category, catC: Category) throws {
        let dbQueue = try DatabaseQueue(configuration: AppDatabase.makeConfiguration())
        let repo = try AppDatabase(dbQueue)

        // To start off, we insert some unrelated Categories for better test robustness
        let catUnrelatedA = try #require(
            try repo.upsert(Category.randomItem(id: UUID().uuidString))
        )
        let catUnrelatedB = try #require(
            try repo.upsert(Category.randomItem(id: UUID().uuidString))
        )

        // At some point the user visits a category that has _only_ a commonsCategory:
        let insertedA = try #require(
            try repo.upsert(catA)
        )

        // The user also visited and bookmarked catA:
        var catAInfo = try repo.updateLastViewed(.init(insertedA), incrementViewCount: true)
        catAInfo = try repo.updateBookmark(catAInfo, bookmark: true)
        #expect(catAInfo.isBookmarked)
        let catALastViewed = try #require(catAInfo.lastViewed)
        #expect(
            Date.now.timeIntervalSince(catALastViewed) < 0.1,
            "We expect catA to have been last viewed in the last 100ms."
        )


        // At a later time, the user visits a category
        // that is _only_ a wikidata item without a linked commonsCategory:
        _ = try repo.upsert(catB)

        // The user views catB (but does not bookmark it):
        let catBInfo = try repo.updateLastViewed(.init(catB), incrementViewCount: true)
        let catBLastViewed = try #require(catBInfo.lastViewed)
        #expect(
            Date.now.timeIntervalSince(catBLastViewed) < 0.1,
            "We expect catB to have been last viewed in the last 100ms and to have been last viewed after catA"
        )

        #expect(
            Date.now.timeIntervalSince(catBLastViewed) < 0.1,
            "We expect catB to have been last viewed after catA"
        )

        let categories = try dbQueue.read(Category.fetchSet)
        print(categories.compactMap { $0.wikidataId ?? $0.commonsCategory })

        #expect(categories.contains(catUnrelatedA))
        #expect(categories.contains(catUnrelatedB))
        #expect(categories.contains { $0.commonsCategory == catA.commonsCategory })
        #expect(categories.contains { $0.wikidataId == catB.wikidataId })

        let count = try dbQueue.read(Category.fetchCount)
        #expect(
            count == 4,
            "We expect 4 categories to exist in the DB: catUnrelatedA, catUnrelatedB, catA, catB"
        )

        // Now at some point Wikidata.org is updated so that the catB, the wikidata item
        // gets linked with the expect commonsCategory:

        // when upserting catC, the desired behaviour is to merge catA and catB with the info of catC,
        // so the user won't see 2 or even 3 individual views for otherwise the same item.
        let insertedC = try #require(try repo.upsert(catC))

        #expect(insertedC.wikidataId == catC.wikidataId)
        #expect(insertedC.commonsCategory == catC.commonsCategory)

        let catCInfo = try repo.fetchCategoryInfo(wikidataID: catC.wikidataId!)
        let bookmarked = catCInfo?.itemInteraction?.bookmarked

        #expect(
            bookmarked != nil,
            "We expect the merged category to be bookmarked, because catA was."
        )

        let lastViewed = catBInfo.itemInteraction?.lastViewed
        #expect(
            lastViewed == catBInfo.lastViewed,
            "We expect the merged category have lastViewed of catB, because that was the last viewed one of A and B."
        )

        let newCount = try dbQueue.read(Category.fetchCount)
        #expect(
            newCount == 3,
            "We expect to have now only categories to exist in the DB: catUnrelatedA, catUnrelatedB, catC (with linked interaction info of catA and catB)"
        )
    }


    @Test(
        "Category upserts with redirections",
        arguments: [
            (
                [
                    Category(wikidataId: "old1", commonsCategory: "old1"),
                    Category(wikidataId: "new1", commonsCategory: "new1"),
                ],
                // redirect: old1 -> new1 etc.
                [
                    "old1": "new1",
                    "other3": "newOther3",
                    "xyz": "abc",
                ]
            ),
            (
                [
                    Category(wikidataId: "other1", commonsCategory: "other1"),
                    Category(wikidataId: "other2", commonsCategory: "other2"),
                    Category(wikidataId: "other3", commonsCategory: "other3"),
                    Category(wikidataId: "old1", commonsCategory: "old1"),
                    Category(wikidataId: "new1", commonsCategory: "new1"),
                    Category(wikidataId: "other4", commonsCategory: "other5"),
                    Category(wikidataId: "newOther3", commonsCategory: "newOther3"),
                ],
                [
                    "old1": "new1",
                    "other3": "newOther3",
                ]
            ),
        ])
    func testUpsertWithRedirection(categories: [Category], redirections: [Category.WikidataID: Category.WikidataID]) throws {
        let dbQueue = try DatabaseQueue(configuration: AppDatabase.makeConfiguration())
        let repo = try AppDatabase(dbQueue)
        let wikidataIDs = categories.compactMap(\.wikidataId)

        #expect(
            try repo.reader.read(Category.fetchCount) == 0,
            "At the start, we expect the db to be empty for a clean test."
        )

        let upsertedCategories = try repo.upsert(categories, handleRedirections: redirections)
        #expect(upsertedCategories.count == categories.count)

        let fetchedItemsWithResolvedRedirects = try repo.fetchCategoryInfos(wikidataIDs: wikidataIDs, resolveRedirections: true)

        // test the redirection fetch to include the target (to-item, instead of from-item) for all upserted items.
        for (from, to) in redirections {
            // Only perform a check if we also attempted to inserted a category matching "to"
            guard categories.contains(where: { $0.wikidataId == to }) else { continue }

            try repo.reader.read { db in
                let fromCatExists =
                    try Category
                    .filter { $0.redirectToWikidataId == to && $0.wikidataId == from }
                    .fetchCount(db) == 1

                #expect(fromCatExists, "We expect that the from-category \(from) exists that redirects to \(to)")

                let toCatExists =
                    try Category
                    .filter { $0.wikidataId == to }
                    .fetchCount(db) == 1

                #expect(toCatExists, "We expect that the to-category \(to) exists is the target of the redirect from \(from)")
            }

            #expect(
                fetchedItemsWithResolvedRedirects.contains { $0.base.wikidataId == from } == false,
                "When fetching with `resolveRedirections=true` we don't expect to find a category with from-id \(from), but only the redirected target item."
            )

            #expect(
                fetchedItemsWithResolvedRedirects.contains { $0.base.wikidataId == to },
                "When fetching with `resolveRedirections=true` we expect to find the target category with to-id \(to)"
            )
        }

        // test for consistency of created redirection Categories in relation to the test argument redirections.
        let allItems = try repo.reader.read(Category.fetchAll)
        for item in allItems {
            if let redirectTo = item.redirectToWikidataId {
                let wikidataID = try #require(item.wikidataId)
                #expect(
                    redirections[wikidataID] == redirectTo,
                    "Categories with `redirectToWikidataId` must be present in the `redirections`-arguments."
                )
            }
        }
    }
}

extension Category: CustomTestStringConvertible {
    var testDescription: String {
        let desc = "\"\(commonsCategory ?? "")\" | \(wikidataId ?? "")"
        return if let id {
            "Category (with id \(id)) | \(desc)"
        } else {
            "Category(without id) | \(desc)"
        }
    }
}

extension MediaFile: CustomTestStringConvertible {
    var testDescription: String {
        "MediaFile \(id) | \(name)"
    }
}
