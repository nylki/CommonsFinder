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
    @Test("MediaFile insert")
    func mediaFileInsert() async throws {
        // Given a properly configured and empty in-memory repo
        let dbQueue = try DatabaseQueue(configuration: AppDatabase.makeConfiguration())
        let repo = try AppDatabase(dbQueue)

        // When we insert an image model
        let insertedItem = try repo.insert(
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
        )

        // Then the inserted MediaFile has the defined id
        #expect(insertedItem.name == "test title")

        // Then the inserted player exists in the database
        let fetchedMediaFile = try await repo.reader.read { db in
            try MediaFile.fetchOne(db, id: insertedItem.id)
        }
        #expect(fetchedMediaFile == insertedItem)

        // Fetching the annotated MediaFileInfo should also work and have a correct MediaFile
        // included.
        let fetchedMediaFileInfo = try repo.fetchMediaFileInfo(id: insertedItem.id)
        #expect(fetchedMediaFileInfo?.mediaFile == insertedItem)
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

    @Test("MediaFileDraft insert")
    func mediaFileDraftInsert() async throws {
        // Given a properly configured and empty in-memory repo
        let dbQueue = try DatabaseQueue(configuration: AppDatabase.makeConfiguration())
        let repo = try AppDatabase(dbQueue)

        // When we insert an image model
        let testName = "Test draft \(Int.random(in: 1..<99999))"
        let draft = MediaFileDraft.makeRandomDraft(id: "test draft", named: testName, date: .init(timeIntervalSince1970: 3600 * 12345))
        let insertedItem = try repo.upsertAndFetch(draft)

        // Then the inserted player has the defined id
        #expect(insertedItem.name == draft.name)

        // Then the inserted player exists in the database
        let fetchedItem = try await repo.reader.read { db in
            try MediaFileDraft.fetchOne(db)
        }

        #expect(fetchedItem != nil)
        #expect(fetchedItem == insertedItem)
    }

}
