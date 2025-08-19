//
//  AppDatabase.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 04.10.24.
//

import Algorithms
import Foundation
import GRDB
import os.log

enum DatabaseError: Error {
    case assertionFailed
    case failedToFetchAfterUpdate
    case failedToCreateOrFetchItemInteraction
    case itemInteractionEmptyID
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

        // See <https://swiftpackageindex.com/groue/grdb.swift.documentation/grdb/databaseschema>
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

        migrator.registerMigration("remove exifData from MediaFileDraft") { db in
            try db.alter(table: "mediaFileDraft") { t in
                t.drop(column: "exifData")
            }
        }


        migrator.registerMigration("reverse itemInteraction association and adjust + rename wikidataItem") { db in


            // 1. Create new itemInteraction table with id and temporary mediaFileId
            try db.create(table: "new_itemInteraction") { t in
                t.column("id", .integer).primaryKey(autoincrement: true)
                t.column("bookmarked", .datetime)
                t.column("lastViewed", .datetime)
                t.column("viewCount", .integer).notNull().defaults(to: 0)

                t.column("mediaFileId", .text).notNull()  // temporary, will be dropped
            }

            // 2. Copy old data into new_itemInteraction, skipping `isBookmarked` because of different type
            try db.execute(
                sql: """
                        INSERT INTO new_itemInteraction (mediaFileId, viewCount, lastViewed)
                        SELECT mediaFileId, viewCount, lastViewed FROM itemInteraction
                    """)

            // 3. Drop old table
            try db.drop(table: "itemInteraction")

            // 4. Rename new table
            try db.rename(table: "new_itemInteraction", to: "itemInteraction")

            try db.alter(table: "mediaFile") { t in
                t.add(column: "itemInteractionId").references("itemInteraction", onDelete: .setNull).indexed()
            }

            // 6. Update mediaFile.itemInteractionId based on matching mediaFileId
            try db.execute(
                sql: """
                    UPDATE mediaFile
                    SET itemInteractionId = (
                        SELECT id FROM itemInteraction WHERE itemInteraction.mediaFileId = mediaFile.id
                    )
                    """
            )

            // 7. drop temp mediaFileId that was needed only for migration
            try db.alter(table: "itemInteraction") { t in
                t.drop(column: "mediaFileId")
            }

            // 8. drop wikidataItem and create new (similiar) category table
            // we drop wikidataItem since it was not used for user-facing features yet
            try db.drop(table: "wikidataItem")

            try db.create(table: "category") { t in
                t.autoIncrementedPrimaryKey("id")

                t.column("commonsCategory", .text).unique()
                t.column("wikidataId", .text).unique()

                t.column("redirectToWikidataId", .text)

                t.column("label", .text)
                t.column("description", .text)
                t.column("aliases", .jsonText)
                t.column("latitude", .numeric)
                t.column("longitude", .numeric)
                t.column("areaSqm", .numeric)

                t.column("instances", .jsonText)
                t.column("image", .text)
                t.column("fetchDate", .datetime)
                t.column("preferredLanguageAtFetchDate", .text)

                /// creates `itemInteractionId` foreign key
                t.belongsTo("itemInteraction", onDelete: .setNull)
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
            // See <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/database/trace/options:_>
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

    /// inserts or updates all mediaFiles while retaining any `itemInteractionID` if it already is set, and returns the inserted media files.
    @discardableResult
    func upsert(_ mediaFiles: [MediaFile]) throws -> [MediaFile] {
        try dbWriter.write { db in
            mediaFiles.compactMap {
                do {
                    // Important: Copies potentially existing itemInteractionID to new mediaFile
                    // so bookmarks etc. don't get lost when upserting:
                    let itemInteractionID =
                        try? MediaFile
                        .filter(id: $0.id)
                        .select(MediaFile.Columns.itemInteractionID, as: Int64.self)
                        .fetchOne(db)

                    var file = $0
                    file.itemInteractionID = itemInteractionID
                    return try file.upsertAndFetch(db)
                } catch {
                    logger.warning("Filed to insert media file \(error)")
                    return nil
                }
            }
        }
    }

    /// updates given mediaFiles but **only  if a MediaFile with the same ID is already present**
    /// The role of this function is to update existing items in the DB with MediaFiles freshly fetched over the network.
    func replaceExistingMediaFiles(_ mediaFiles: [MediaFile]) throws {
        let existingIDs: Set<String> = try dbWriter.read { db in
            return
                try MediaFile
                .filter(ids: mediaFiles.map(\.id))
                .select(\.id, as: MediaFile.ID.self)
                .fetchSet(db)
        }

        let mediaFilesToUpsert = mediaFiles.filter { mediaFile in
            existingIDs.contains(mediaFile.id)
        }
        try upsert(mediaFilesToUpsert)
    }

    /// Deletes the file.
    func delete(_ imageModel: MediaFile) throws -> Bool {
        try dbWriter.write(imageModel.delete)
    }

    /// Deletes all files.
    func deleteAllImageModels() throws -> Int {
        try dbWriter.write(MediaFile.deleteAll)
    }
}

// MARK: - MediaFileInfo Writes
extension AppDatabase {
    /// creates a new DB entry if needed
    func updateLastViewed(_ mediaFileInfo: MediaFileInfo) throws -> MediaFileInfo {
        try updateInteractionImpl(mediaFileInfo, lastViewed: .now, incrementViewCount: true)
    }

    /// creates a new DB entry if needed
    func updateBookmark(_ mediaFileInfo: MediaFileInfo, bookmark: Bool) throws -> MediaFileInfo {
        try updateInteractionImpl(mediaFileInfo, isBookmarked: bookmark)
    }

    /// Updates MediaFile interactions and also *will create entry in DB if it does not exist yet*
    private func updateInteractionImpl(_ mediaFileInfo: MediaFileInfo, isBookmarked: Bool? = nil, lastViewed: Date? = nil, incrementViewCount: Bool = false) throws -> MediaFileInfo {
        let mediaFileID = mediaFileInfo.mediaFile.id

        return try dbWriter.write { db in
            var itemInteraction =
                if let existingInteraction = try ItemInteraction.fetchOne(db, id: mediaFileInfo.itemInteraction?.id) {
                    existingInteraction
                } else {
                    try ItemInteraction().inserted(db)
                }

            guard let itemInteractionID = itemInteraction.id else {
                throw DatabaseError.itemInteractionEmptyID
            }

            if let lastViewed {
                itemInteraction.lastViewed = lastViewed
            }

            if incrementViewCount {
                itemInteraction.viewCount = min(itemInteraction.viewCount + 1, UInt.max)
            }

            if let isBookmarked {
                itemInteraction.bookmarked = isBookmarked ? .now : nil
            }

            try itemInteraction.upsert(db)

            // If the mediaFile was not interacted before, it now gets linked with the itemInteraction
            // via the itemInteractionID (foreign key):
            if mediaFileInfo.mediaFile.itemInteractionID == nil {
                var updatedMediaFile = mediaFileInfo.mediaFile
                updatedMediaFile.itemInteractionID = itemInteractionID
                try updatedMediaFile.upsert(db)
            }

            let freshMediaFileInfo =
                try MediaFile
                .filter(id: mediaFileID)
                .including(required: MediaFile.itemInteraction)
                .asRequest(of: MediaFileInfo.self)
                .fetchOne(db)

            guard let freshMediaFileInfo else {
                assertionFailure("Failed to fetch base mediaFile after updating usage. Should not happen.")
                throw DatabaseError.failedToFetchAfterUpdate
            }

            return freshMediaFileInfo
        }
    }
}

// MARK: - Category Writes
extension AppDatabase {
    @discardableResult
    func upsert(_ item: Category) throws -> Category? {
        try upsert([item]).first
    }

    /// inserts or updates all Categories while retaining any `itemInteractionID` if it already is set, and returns the inserted media files.
    /// Optionally also creates redirect items (as returned from the API), expecting the format [fromWikidataID:toWikidataID] in the same transaction.

    @discardableResult
    func upsert(_ items: [Category], redirectItemsAfterUpsert redirectItems: [Category.WikidataID: Category.WikidataID]? = nil) throws -> [Category] {

        try dbWriter.write { db in
            let resultIDs = items.compactMap { item in
                do {
                    if let redirectToWikidataId = item.redirectToWikidataId {
                        logger.debug("redirectToWikidataId \(redirectToWikidataId)")
                    }
                    // When upserting Categories we have to check if an item already exists that
                    // (in order of importance) has the same:
                    // 1. id (database id, only applicable if the item to upsert was itself already in the DB)
                    // 2. wikidataId
                    // 3. commonsCategory
                    // this is what `findExistingCategory(basedOn: )` does.

                    // If an item matching one of the above exists, we must copy the itemInteractionID
                    // before upserting (and in effect replacing the existing one).

                    let existingCategories =
                        try Category
                        .findExistingCategory(basedOn: item)
                        .fetchAll(db)

                    if existingCategories.count < 2 {
                        let existingCategory = existingCategories.first
                        var itemCopy = item
                        itemCopy.commonsCategory = item.commonsCategory ?? existingCategory?.commonsCategory
                        itemCopy.wikidataId = item.wikidataId ?? existingCategory?.wikidataId
                        itemCopy.id = item.id ?? existingCategory?.id
                        itemCopy.itemInteractionID = item.itemInteractionID ?? existingCategory?.itemInteractionID

                        return try itemCopy.upsertAndFetch(db).id
                    } else {
                        // We need to merge multiple items
                        let existingCategoryInfos: [CategoryInfo] =
                            try Category
                            .filter(ids: existingCategories.compactMap(\.id))
                            .including(optional: Category.itemInteraction)
                            .asRequest(of: CategoryInfo.self)
                            .fetchAll(db)

                        // We choose a reference item from the currently existing ones in the db,
                        // preferring one that has already an interaction.
                        let refCategoryInfo = existingCategoryInfos.first { $0.itemInteraction != nil } ?? existingCategoryInfos.first
                        let refItemInteraction = refCategoryInfo?.itemInteraction
                        guard let refCategoryInfo, let refCategoryID = refCategoryInfo.base.id else {
                            assertionFailure("We expect items fetched from the DB to always have an (autoincremented) id.")
                            throw DatabaseError.assertionFailed
                        }

                        // 1. First we combine all previous interactions, of categories to be merged,
                        // into one:
                        var mergeItemInteraction: ItemInteraction = refItemInteraction ?? .init()
                        for existingInteraction in existingCategoryInfos.compactMap(\.itemInteraction) {
                            // Assign the `isBookmarked` if any interaction was bookmarked
                            if let bookmarked = existingInteraction.bookmarked {
                                mergeItemInteraction.bookmarked = bookmarked
                            }
                            // Choose the max `viewCount`
                            mergeItemInteraction
                                .viewCount = max(existingInteraction.viewCount, mergeItemInteraction.viewCount)

                            // Choose the most recent (max) `lastViewed`
                            if let lastViewed = existingInteraction.lastViewed {
                                if let mergeLastViewed = mergeItemInteraction.lastViewed {
                                    mergeItemInteraction.lastViewed = max(lastViewed, mergeLastViewed)
                                } else {
                                    mergeItemInteraction.lastViewed = lastViewed
                                }
                            }
                        }

                        // 2. Now that we have our final mergeItemInteraction
                        // we delete the ones that are not needed anymore.
                        let interactionIdsToDelete =
                            existingCategoryInfos
                            .compactMap(\.itemInteraction?.id)
                            .filter { mergeItemInteraction.id != $0 }

                        let deletedInteractionCount = try ItemInteraction.deleteAll(db, ids: interactionIdsToDelete)
                        assert(deletedInteractionCount == interactionIdsToDelete.count)

                        // and finally upsert the merged interaction
                        mergeItemInteraction = try mergeItemInteraction.upsertAndFetch(db)

                        // 3. Now we merge the base Category.
                        // We want the fields from the new item, so copy that one first
                        var mergeCategory = item
                        // and assign it the `id` and `itemInteractionID` of the existing entry that was choosen.
                        mergeCategory.id = refCategoryID
                        mergeCategory.itemInteractionID = refItemInteraction?.id

                        // 5. Delete all Categories that are not needed anymore
                        let categoryIdsToRemove: [Int64] =
                            existingCategories
                            .compactMap(\.id)
                            .filter { $0 != mergeCategory.id }

                        let deletedCategoriesCount = try Category.deleteAll(db, ids: categoryIdsToRemove)
                        assert(deletedCategoriesCount == categoryIdsToRemove.count)

                        // 6. Finally upsert the new merged Category
                        mergeCategory = try mergeCategory.upsertAndFetch(db)
                        assert(mergeCategory.id == refCategoryID)
                        assert(mergeCategory.itemInteractionID == mergeItemInteraction.id)

                        return mergeCategory.id
                    }

                } catch {
                    logger.warning("Failed to insert category \(error)")
                    return nil
                }
            }

            /// handle redirections before returning values
            ///
            /// FIXME: i prefer to have these in the same transaction, but it make this function rather long
            /// can we still split this up, while keeping them in the same transaction to be safer?
            if let redirectItems {
                for (fromWikidataID, toWikidataID) in redirectItems {
                    // This item will replace the original "from" item and poinst to the "to" item
                    var redirectingCategory = Category(
                        wikidataID: fromWikidataID,
                        redirectsTo: toWikidataID
                    )

                    let existingFromInfo = try CategoryInfo.filter(wikidataID: fromWikidataID).fetchOne(db)
                    let existingToInfo = try CategoryInfo.filter(wikidataID: toWikidataID).fetchOne(db)

                    try redirectingCategory.upsert(db)

                    guard var existingToInfo else {
                        logger.debug("No  target item of the redirection exists to rewrite interaction.")
                        continue
                    }

                    // Now we rewrite the interactionID if the redirected item had any.
                    // if the to-item also has an interaction, we merge fields from
                    if let existingFromInteraction = existingFromInfo?.itemInteraction {

                        if var existingToInteraction = existingToInfo.itemInteraction {
                            // to-item already has interactions, we merge the previous one into the target
                            existingToInteraction = existingToInteraction.merge(with: existingFromInteraction)
                            try existingToInteraction.update(db)
                            // and then delete the old interaction that won't be needed anymore.
                            try existingFromInteraction.delete(db)
                        } else {
                            // otherwise re-use the interaction of the previous item
                            existingToInfo.base.itemInteractionID = existingFromInteraction.id
                            try existingToInfo.base.upsert(db)

                        }
                    }


                }
            }

            return try Category.fetchAll(db, ids: resultIDs)
        }
    }


    func adjustInteractions(forRedirections redirections: [Category.WikidataID: Category.WikidataID]) throws {
        //        guard !redirections.isEmpty else { return }
        //        var itemsToAdjust = try fetchCategoryInfos(wikidataIDs: redirections.map(\.key))
        //        guard !itemsToAdjust.isEmpty else { return }
        //
        //        itemsToAdjust = itemsToAdjust.map({ <#CategoryInfo#> in
        //            <#code#>
        //        })
        //
        //        try dbWriter.write { db in
        //
        //        }
        //
        //        for (from, to) in redirections {
        //
        //        }
    }

    func delete(_ category: Category) throws -> Bool {
        try dbWriter.write(category.delete)
    }

}

// MARK: - CategoryInfo Writes
extension AppDatabase {
    /// creates a new DB entry if needed
    func updateLastViewed(_ item: CategoryInfo) throws -> CategoryInfo {
        try updateInteractionImpl(item, lastViewed: .now, incrementViewCount: true)
    }

    /// creates a new DB entry if needed
    @discardableResult
    func updateBookmark(_ item: CategoryInfo, bookmark: Bool) throws -> CategoryInfo {
        try updateInteractionImpl(item, isBookmarked: bookmark)
    }

    /// Updates MediaFile interactions and also *will create entry in DB if it does not exist yet*
    private func updateInteractionImpl(_ item: CategoryInfo, isBookmarked: Bool? = nil, lastViewed: Date? = nil, incrementViewCount: Bool = false) throws -> CategoryInfo {
        return try dbWriter.write { db in

            let databaseItem: CategoryInfo? =
                try Category
                .findExistingCategory(basedOn: item.base)
                .including(optional: Category.itemInteraction)
                .asRequest(of: CategoryInfo.self)
                .fetchOne(db)

            var workItem: CategoryInfo

            if let databaseItem {
                workItem = databaseItem
            } else {
                let insertedCategory = try item.base.inserted(db)
                workItem = .init(insertedCategory, itemInteraction: nil)
            }

            var itemInteraction = workItem.itemInteraction ?? .init()

            if let lastViewed {
                itemInteraction.lastViewed = lastViewed
            }

            if incrementViewCount {
                itemInteraction.viewCount = min(itemInteraction.viewCount + 1, UInt.max)
            }

            if let isBookmarked {
                itemInteraction.bookmarked = isBookmarked ? .now : nil
            }

            try itemInteraction.upsert(db)

            // If the mediaFile was not interacted before, it now gets linked with the itemInteraction
            // via the itemInteractionID (foreign key):
            if workItem.itemInteraction == nil {
                try workItem.base.updateChanges(db) {
                    $0.itemInteractionID = itemInteraction.id
                }
            }

            let freshWikidataItemInfo =
                try Category
                .filter(id: workItem.base.id)
                .including(required: Category.itemInteraction)
                .asRequest(of: CategoryInfo.self)
                .fetchOne(db)

            guard let freshWikidataItemInfo else {
                assertionFailure("Failed to fetch base freshWikidataItem after updating usage. Should not happen.")
                throw DatabaseError.failedToFetchAfterUpdate
            }

            return freshWikidataItemInfo
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

    func fetchRecentlyViewedMediaFileInfos(order: BasicOrdering) throws -> [MediaFileInfo] {
        try dbWriter.read { db in
            let request =
                switch order {
                case .asc: MediaFile.including(required: MediaFile.itemInteraction.order(\.lastViewed.asc))
                case .desc: MediaFile.including(required: MediaFile.itemInteraction.order(\.lastViewed.desc))
                }

            return
                try request
                .asRequest(of: MediaFileInfo.self)
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

    func fetchCategoryInfo(commonsCategory: String) throws -> CategoryInfo? {
        try dbWriter.read { db in
            try Category
                .filter(Category.Columns.commonsCategory == commonsCategory)
                .including(optional: Category.itemInteraction)
                .asRequest(of: CategoryInfo.self)
                .fetchOne(db)
        }
    }

    func fetchCategoryInfo(wikidataID: String, resolveRedirections: Bool = true) throws -> CategoryInfo? {
        try fetchCategoryInfos(
            wikidataIDs: [wikidataID],
            resolveRedirections: resolveRedirections
        )
        .first
    }

    func fetchCategoryInfos(commonsCategories: [String]) throws -> [CategoryInfo] {
        try dbWriter.read { db in
            try Category
                .filter(commonsCategories.contains(Category.Columns.commonsCategory))
                .including(optional: Category.itemInteraction)
                .asRequest(of: CategoryInfo.self)
                .fetchAll(db)
        }
    }

    func fetchCategoryInfos(wikidataIDs: [Category.WikidataID], resolveRedirections: Bool) throws -> [CategoryInfo] {
        try dbWriter.read { db in
            try CategoryInfo.fetchAll(db, wikidataIDs: wikidataIDs, resolveRedirections: resolveRedirections)
        }
    }

    func fetchRecentlyViewedCategoryInfos(order: BasicOrdering) throws -> [CategoryInfo] {
        try dbWriter.read { db in
            let request =
                switch order {
                case .asc: Category.including(required: Category.itemInteraction.order(\.lastViewed.asc))
                case .desc: Category.including(required: Category.itemInteraction.order(\.lastViewed.desc))
                }

            return
                try request
                .asRequest(of: CategoryInfo.self)
                .fetchAll(db)
        }
    }

    func fetchBookmarkedCategoryInfos() throws -> [CategoryInfo] {
        try dbWriter.read { db in
            try Category.including(required: Category.itemInteraction)
                .asRequest(of: CategoryInfo.self)
                .fetchAll(db)
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

extension CategoryInfo {
    /// takes redirections into account
    static func fetchAll(_ db: Database, wikidataIDs: [Category.WikidataID], resolveRedirections: Bool) throws -> [Self] {
        let ids: [Category.WikidataID]

        if resolveRedirections {
            let redirects =
                try Category
                .filter(wikidataIDs.contains(Category.Columns.wikidataId))
                .filter { $0.redirectToWikidataId != nil }
                .fetchAll(db)
                .grouped(by: \.wikidataId)

            ids = wikidataIDs.map {
                redirects[$0]?.first?.redirectToWikidataId ?? $0
            }
        } else {
            ids = wikidataIDs
        }

        return
            try CategoryInfo
            .filter(wikidataIDs: ids)
            .fetchAll(db)
    }
}
