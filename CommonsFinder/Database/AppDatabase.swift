//
//  AppDatabase.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 04.10.24.
//

import Foundation
import GRDB
import os.log

enum DatabaseError: Error {
    case assertionFailed
    case failedToFetchAfterUpdate
}

/// The AppDatabase holding image models, drafts and user info.
/// See https://github.com/groue/GRDBQuery/tree/main/Documentation for the reference demo implementations.

final class AppDatabase: Sendable {
    /// Access to the database.
    ///
    /// Application can use a `DatabasePool`, while SwiftUI previews and tests
    /// can use a fast in-memory `DatabaseQueue`.
    ///
    /// See <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseconnections>
    private let dbWriter: any DatabaseWriter

    /// Creates a `AppDatabase(`, and makes sure the database schema
    /// is ready.
    ///
    /// - important: Create the `DatabaseWriter` with a configuration
    ///   returned by ``makeConfiguration(_:)``.
    public init(_ dbWriter: some GRDB.DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
    }


    /// The DatabaseMigrator that defines the database schema.
    ///
    /// See <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/migrations>
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        #if DEBUG
            // Speed up development by nuking the database when migrations change
            // See <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/migrations#The-eraseDatabaseOnSchemaChange-Option>
            migrator.eraseDatabaseOnSchemaChange = true
        #endif

        // See <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseschema>
        migrator.registerMigration("initial schema") { db in
            try db.create(table: "mediaFile") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("fetchDate", .text).notNull()
                t.column("username", .text)
                t.column("mimeType", .text)
                t.column("width", .integer)
                t.column("height", .integer)
                t.column("uploadDate", .datetime)
                t.column("fullDescriptions", .jsonText)
                t.column("categories", .jsonText)
                t.column("statements", .jsonText)
                t.column("captions", .jsonText)
                t.column("descriptionURL", .text)
                t.column("url", .text)
                t.column("thumbURL", .text)
                t.column("license")
                t.column("rawAttribution", .text)
            }


            try db.create(virtualTable: "mediaFile_ft", using: FTS5()) { t in  // or FTS4(), or FTS5()
                t.tokenizer = LatinAsciiTokenizer.tokenizerDescriptor()
                t.synchronize(withTable: "mediaFile")
                t.column("fullDescriptions")
                t.column("categories")
                t.column("captions")
                t.column("username")
            }

            try db.create(table: "mediaFileDraft") { t in
                t.primaryKey("id", .text).notNull()
                t.column("addedDate", .datetime).notNull()
                t.column("exifData", .jsonText)

                t.column("name", .text).notNull()
                // Must be unique when uploading to commons:
                // https://commons.wikimedia.org/wiki/Commons:File_naming
                t.column("finalFilename", .text).notNull()

                t.column("username", .text)

                t.column("localFileName", .text)
                t.column("mimeType", .text)

                t.column("inceptionDate", .datetime)
                t.column("timezone", .text)
                t.column("captionWithDesc", .jsonText)
                t.column("tags", .jsonText)

                t.column("locationHandling", .jsonText).notNull()

                t.column("license", .text)
                t.column("author", .jsonText)
                t.column("source", .jsonText)

                t.column("width", .integer)
                t.column("height", .integer)
            }

            try db.create(virtualTable: "mediaFileDraft_ft", using: FTS5()) { t in  // or FTS4(), or FTS5()
                t.tokenizer = LatinAsciiTokenizer.tokenizerDescriptor()
                t.synchronize(withTable: "mediaFileDraft")
                t.column("name")
                t.column("inceptionDate")
                t.column("captionWithDesc")
                t.column("tags")
                t.column("username")
            }

            try db.create(table: "wikidataItem") { t in
                t.primaryKey("id", .text).notNull()
                t.column("label", .text)
                t.column("description", .text)
                t.column("aliases", .jsonText)
                t.column("latitude", .numeric)
                t.column("longitude", .numeric)
                t.column("commonsCategory", .text)
                t.column("instances", .jsonText)
                t.column("image", .text)
                t.column("fetchDate", .datetime)
                t.column("preferredLanguageAtFetchDate", .text)
            }

            try db.create(table: "itemInteraction") { t in
                // relates to mediaFileId
                t.belongsTo("mediaFile", onDelete: .cascade)
                    .unique()

                // relates to wikidataItemId
                t.belongsTo("wikidataItem", onDelete: .cascade)
                    .unique()

                t.column("isBookmarked", .boolean).notNull().defaults(to: false)
                t.column("lastViewed", .datetime)
                t.column("viewCount", .integer).notNull().defaults(to: 0)
            }
        }

        return migrator
    }
}

// MARK: - Configuration

extension AppDatabase {
    private static let sqlLogger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "SQL")

    /// Returns a database configuration suited for `AppDatabase`.
    ///
    /// SQL statements are logged if the `SQL_TRACE` environment variable
    /// is set.
    ///
    /// - parameter base: A base configuration.
    static func makeConfiguration(_ base: Configuration = Configuration()) -> Configuration {
        var config = base

        // An opportunity to add required custom SQL functions or
        // collations, if needed:
        // config.prepareDatabase { db in
        //     db.add(function: ...)
        // }

        config.prepareDatabase { db in
            // Create full-text tables
            db.add(tokenizer: LatinAsciiTokenizer.self)

            // Log SQL statements if the `SQL_TRACE` environment variable is set.
            // See <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/database/trace(options:_:)>
            if ProcessInfo.processInfo.environment["SQL_TRACE"] != nil {
                db.trace {
                    // It's ok to log statements publicly. Sensitive
                    // information (statement arguments) are not logged
                    // unless config.publicStatementArguments is set
                    // (see below).
                    os_log("%{public}@", log: sqlLogger, type: .debug, String(describing: $0))
                }
            }
        }


        #if DEBUG
            // Protect sensitive information by enabling verbose debugging in
            // DEBUG builds only.
            // See <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/configuration/publicstatementarguments>
            config.publicStatementArguments = true
        #endif

        return config
    }
}

// MARK: - MediaFile Writes

extension AppDatabase {
    /// Inserts a media file and returns the inserted media file.
    @discardableResult
    func insert(_ imageModel: MediaFile) throws -> MediaFile {
        try dbWriter.write { db in
            try imageModel.inserted(db)
        }
    }

    /// Inserts multiple media files and returns the inserted media files.
    @discardableResult
    func upsert(_ mediaFiles: [MediaFile]) throws -> [MediaFile] {
        try dbWriter.write { db in
            mediaFiles.compactMap {
                do {
                    var file = $0
                    return try file.upsertAndFetch(db)
                } catch {
                    logger.warning("Filed to insert media file \(error)")
                    return nil
                }
            }
        }
    }

    /// Updates the file.
    func update(_ imageModel: MediaFile) throws {
        try dbWriter.write { db in
            try imageModel.update(db)
        }
    }

    /// Deletes the file.
    func delete(_ imageModel: MediaFile) throws {
        try dbWriter.write { db in
            _ = try imageModel.delete(db)
        }
    }

    /// Deletes all files.
    func deleteAllImageModels() throws {
        try dbWriter.write { db in
            _ = try MediaFile.deleteAll(db)
        }
    }
}

// MARK: - MediaFileInfo Writes
extension AppDatabase {
    /// Updates MediaFile.lastViewed to .now, *will create entry in DB if it does not exist yet*
    func saveAsRecentlyViewed(_ mediaFileInfo: MediaFileInfo) throws -> MediaFileInfo {
        let id = mediaFileInfo.id
        var existingMediaFile = mediaFileInfo.mediaFile
        return try dbWriter.write { db in
            try existingMediaFile.upsert(db)
            let existingMetadata = try? ItemInteraction.find(db, id: id)
            var metadata = existingMetadata ?? ItemInteraction(mediaFileId: id)

            metadata.lastViewed = .now
            metadata.viewCount = min(metadata.viewCount + 1, UInt.max)

            _ = try metadata.upsertAndFetch(db)
            let mediaFile = try MediaFile.fetchOne(db, id: id)

            guard let mediaFile else {
                assertionFailure("Failed to fetch base mediaFile after updating usage. Should not happen.")
                throw DatabaseError.failedToFetchAfterUpdate
            }

            return .init(mediaFile: mediaFile, itemInteraction: metadata)
        }
    }
}

// MARK: - WikidataItem Writes
extension AppDatabase {
    func upsert(_ item: WikidataItem) throws {
        try dbWriter.write { db in
            var item = item
            try item.upsert(db)
        }
    }

    func upsert(_ items: [WikidataItem]) throws {
        try dbWriter.write { db in
            for item in items {
                var item = item
                try item.upsert(db)
            }
        }
    }
}

// MARK: - MediaFileDraft Writes
extension AppDatabase {
    func update(_ draft: MediaFileDraft) throws {
        try dbWriter.write { db in
            try draft.update(db)
        }
    }

    func upsert(_ draft: MediaFileDraft) throws {
        try dbWriter.write { db in
            var draft = draft
            try draft.upsert(db)
        }
    }

    func upsertAndFetch(_ draft: MediaFileDraft) throws -> MediaFileDraft {
        try dbWriter.write { db in
            var draft = draft
            return try draft.upsertAndFetch(db)
        }
    }

    func delete(_ draft: MediaFileDraft) throws {
        try dbWriter.write { db in
            _ = try draft.delete(db)
        }
    }

    func delete(_ drafts: [MediaFileDraft]) throws {
        try dbWriter.write { db in
            _ = try MediaFileDraft.deleteAll(db, ids: drafts.map(\.id))
        }
    }

    /// Deletes all files by finalFilename, returns the number of deleted files
    func deleteDrafts(withFinalFilenames filenames: [String]) throws -> Int {
        try dbWriter.write { db in
            try MediaFileDraft
                .filter(filenames.contains(MediaFileDraft.Columns.finalFilename))
                .deleteAll(db)
        }
    }
}

// MARK: - Access: Reads

// This app currently does not provide any specific reading method, and instead
// gives an unrestricted read-only access to the rest of the application.
// In your app, you are free to choose another path, and define focused
// reading methods.
extension AppDatabase {
    /// Provides a read-only access to the database.
    var reader: any GRDB.DatabaseReader {
        dbWriter
    }

    func fetchMediaFileInfo(id: String) throws -> MediaFileInfo? {
        try dbWriter.read { db in
            try MediaFile
                .filter(id: id)
                .including(optional: MediaFile.itemInteraction)
                .asRequest(of: MediaFileInfo.self)
                .fetchOne(db)

        }
    }

    func fetchMediaFileInfos(ids: [String]) throws -> [MediaFileInfo] {
        try dbWriter.read { db in
            try MediaFile
                .filter(ids: ids)
                .including(optional: MediaFile.itemInteraction)
                .asRequest(of: MediaFileInfo.self)
                .fetchAll(db)
        }
    }

    enum BasicOrdering {
        case asc
        case desc
    }

    func fetchOrderedMediaFileIDs(order: BasicOrdering) throws -> [String] {
        try dbWriter.read { db in
            var orderedIdsRequest = ItemInteraction.filter { $0.lastViewed != nil }

            orderedIdsRequest =
                switch order {
                case .asc: orderedIdsRequest.order(\.lastViewed.asc)
                case .desc: orderedIdsRequest.order(\.lastViewed.desc)
                }

            return
                try orderedIdsRequest
                .select(\.mediaFileId, as: String.self)
                .fetchAll(db)
        }
    }

    func fetchAllFiles(byUsername username: String, withNames names: [String]) throws -> [MediaFile] {
        try dbWriter.read { db in
            try MediaFile
                .filter(MediaFile.Columns.username == username)
                .filter(names.contains(MediaFile.Columns.name))
                .fetchAll(db)
        }
    }

    /// FTS5 match
    func fetchAllFiles(matchingPhrase phrase: String) throws -> [MediaFile] {
        let sql = """
                SELECT mediaFile.*
                FROM mediaFile
                JOIN mediaFile_ft
                    ON mediaFile_ft.rowid = mediaFile.rowid
                    AND mediaFile_ft MATCH ? ORDER BY rank
            """


        return try dbWriter.read { db in
            let pattern = FTS5Pattern(matchingAllPrefixesIn: phrase)
            return try MediaFile.fetchAll(db, sql: sql, arguments: [pattern])
        }
    }

    func fetchAllDrafts() throws -> [MediaFileDraft] {
        try dbWriter.read { db in
            try MediaFileDraft
                .fetchAll(db)
        }
    }

    func fetchMostRecentUploadDate(byUsername username: String) throws -> Date? {
        try dbWriter.read { db in
            try MediaFile
                .filter(MediaFile.Columns.username == username)
                .order(MediaFile.Columns.uploadDate.desc)
                .select(MediaFile.Columns.uploadDate, as: Date.self)
                .fetchOne(db)
        }
    }
}

extension MediaFileInfo {
    static func fetchAll(ids: [String], db: Database) throws -> [Self] {
        try MediaFile
            .filter(ids: ids)
            .including(optional: MediaFile.itemInteraction)
            .asRequest(of: MediaFileInfo.self)
            .fetchAll(db)
    }
}
