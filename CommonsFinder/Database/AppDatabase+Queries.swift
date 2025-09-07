//
//  AppDatabase+Queries.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.08.25.
//

import Foundation
import GRDB
import GRDBQuery
import os.log

// MARK: - Queries


/// A @Query request that observes all drafts in the database
struct AllDraftsRequest: ValueObservationQueryable {
    static var defaultValue: [MediaFileDraft] { [] }

    func fetch(_ db: Database) throws -> [MediaFileDraft] {
        do {
            return
                try MediaFileDraft
                .order(MediaFileDraft.Columns.addedDate.desc)
                //                .order(\.addedDate.desc)
                .fetchAll(db)
        } catch {
            logger.error("Failed to fetch all draft files from db \(error)!")
            return []
        }
    }
}

/// A @Query request that observes all uploads by username in the database
struct AllUploadsRequest: ValueObservationQueryable {
    var username: String = ""
    static var defaultValue: [MediaFileInfo] { [] }

    func fetch(_ db: Database) throws -> [MediaFileInfo] {
        do {
            let allFiles =
                try MediaFile
                .filter(MediaFile.Columns.username == username)
                .order(MediaFile.Columns.uploadDate.desc)
                .including(optional: MediaFile.itemInteraction)
                .asRequest(of: MediaFileInfo.self)
                .fetchAll(db)

            return allFiles
        } catch {
            logger.error("Failed to fetch all uploaded files from db \(error)!")
            return []
        }
    }
}

/// A @Query request that observes all media items in the database
struct AllRecentlyViewedMediaFileRequest: ValueObservationQueryable {
    static var defaultValue: [MediaFileInfo] { [] }

    func fetch(_ db: Database) throws -> [MediaFileInfo] {
        return
            try MediaFile
            .including(required: MediaFile.itemInteraction.order(\.lastViewed.desc))
            .asRequest(of: MediaFileInfo.self)
            .fetchAll(db)
    }
}

/// A @Query request that observes all wiki items in the database
struct AllRecentlyViewedWikiItemsRequest: ValueObservationQueryable {
    static var defaultValue: [CategoryInfo] { [] }

    func fetch(_ db: Database) throws -> [CategoryInfo] {
        try Category
            .including(required: Category.itemInteraction.order(\.lastViewed.desc))
            .asRequest(of: CategoryInfo.self)
            .fetchAll(db)
    }
}

/// A @Query request that observes all bookmarked media items in the database
struct AllBookmarksFileRequest: ValueObservationQueryable {
    static var defaultValue: [MediaFileInfo] { [] }

    func fetch(_ db: Database) throws -> [MediaFileInfo] {
        try MediaFile
            .including(
                required: MediaFile
                    .itemInteraction
                    .filter { $0.bookmarked != nil }
                    .order(\.bookmarked.desc)
            )
            .asRequest(of: MediaFileInfo.self)
            .fetchAll(db)
    }
}

/// A @Query request that observes all bookmarked wiki items in the database
struct AllBookmarksWikiItemRequest: ValueObservationQueryable {
    static var defaultValue: [CategoryInfo] { [] }

    func fetch(_ db: Database) throws -> [CategoryInfo] {
        try Category
            .all()
            .includeInteractionsWithBookmarks()
            .fetchAll(db)
    }
}

nonisolated extension QueryInterfaceRequest<Category> {
    func includeInteractionsWithBookmarks() -> QueryInterfaceRequest<CategoryInfo> {
        Category
            .including(
                required: Category
                    .itemInteraction
                    .filter { $0.bookmarked != nil }
                    .order(\.bookmarked.desc)
            )
            .asRequest(of: CategoryInfo.self)
    }
}

/// A @Query request that observes a single media item in the database
struct MediaFileRequest: ValueObservationQueryable {
    let id: String
    static var defaultValue: MediaFile? { nil }

    func fetch(_ db: Database) throws -> MediaFile? {
        try MediaFile
            .fetchOne(db, id: id)
    }
}


nonisolated extension Category {
    /// filters existing Categories based on id, wikidataId, commonsCategory of given Categories
    static func filter(basedOn categories: [Category]) -> QueryInterfaceRequest<Self> {
        let ids = Set(categories.compactMap(\.id))
        let wikidataIDs = Set(categories.compactMap(\.wikidataId))
        let commonsCategories = Set(categories.compactMap(\.commonsCategory))

        return Category.filter {
            ids.contains($0.id) || wikidataIDs.contains($0.wikidataId) || commonsCategories.contains($0.commonsCategory)
        }
    }

    /// filters existing Category based on id, wikidataId, commonsCategory
    static func filter(basedOn category: Category) -> QueryInterfaceRequest<Self> {
        filter(basedOn: [category])
    }
}

nonisolated extension CategoryInfo {
    static func filter(wikidataID: Category.WikidataID) -> QueryInterfaceRequest<Self> {
        Category
            .filter { $0.wikidataId == wikidataID }
            .including(optional: Category.itemInteraction)
            .asRequest(of: CategoryInfo.self)
    }

    static func filter(wikidataIDs: [Category.WikidataID]) -> QueryInterfaceRequest<Self> {
        let idSet = Set(wikidataIDs)
        return
            Category
            .filter { idSet.contains($0.wikidataId) }
            .including(optional: Category.itemInteraction)
            .asRequest(of: CategoryInfo.self)
    }
}


// TODO: rethink this, similar to horizontal list?
//struct MediaFileListRequest: ValueObservationQueryable {
//    let queryType: QueryType
//    var filterString: String = ""
//
//    static var defaultValue: [MediaFileInfo] { [] }
//
//    enum QueryType: Equatable, Hashable {
//        case recentlyViewedMedia
//    }
//
//    func fetch(_ db: Database) throws -> [MediaFileInfo] {
//        switch queryType {
//        case .recentlyViewedMedia:
//
//            let orderedMediaFileUserMetadata = MediaFile.itemInteraction
//                .filter { $0.lastViewed != nil }
//                .order(\.lastViewed.desc)
//
//            let allFiles =
//                MediaFile
//                .including(required: orderedMediaFileUserMetadata)
//                .asRequest(of: MediaFileInfo.self)
//
//
//            //            if !filterString.isEmpty {
//            //                let sql = """
//            //                        SELECT mediaFile.*
//            //                        FROM mediaFile
//            //                        JOIN mediaFile_ft
//            //                            ON mediaFile_ft.rowid = mediaFile.rowid
//            //                            AND mediaFile_ft MATCH ? ORDER BY rank
//            //                    """
//            //
//            //
//            //                let pattern = FTS5Pattern(matchingAllPrefixesIn: filterString)
//            //
//            //                return try allFiles
//            //                    .filter(sql: sql, arguments: [pattern])
//            //                    .fetchAll(db)
//            //            }
//
//            return try allFiles.fetchAll(db)
//        }
//    }
//}
