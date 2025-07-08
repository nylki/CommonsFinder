//
//  AppDatabase+SwiftUI.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 04.10.24.
//

import GRDB
import GRDBQuery
import SwiftUI
import os.log

// MARK: - Give SwiftUI access to the AppDatabase

// Define a new environment key that grants access to a `AppDatabase`.
// The technique is documented at
// <https://developer.apple.com/documentation/swiftui/environmentvalues/>.
extension EnvironmentValues {
    @Entry var appDatabase: AppDatabase = .empty()
}

extension View {
    /// Sets both the `database` (for writes) and `databaseContext`
    /// (for `@Query`) environment values.
    ///
    func appDatabase(_ repository: AppDatabase) -> some View {
        self
            .environment(\.appDatabase, repository)
            .databaseContext(.readOnly { repository.reader })
    }
}

// MARK: - Queries


/// A @Query request that observes all drafts in the database
struct AllDraftsRequest: ValueObservationQueryable {
    static var defaultValue: [MediaFileDraft] { [] }

    func fetch(_ db: Database) throws -> [MediaFileDraft] {
        do {
            return
                try MediaFileDraft
                .order(MediaFileDraft.Columns.addedDate)
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
            .including(
                required: Category
                    .itemInteraction
                    .filter { $0.bookmarked != nil }
                    .order(\.lastViewed.desc)
            )
            .asRequest(of: CategoryInfo.self)
            .fetchAll(db)
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
