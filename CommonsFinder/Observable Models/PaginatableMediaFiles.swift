//
//  PaginatableSearchMediaFiles.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.12.24.
//

import Algorithms
import CommonsAPI
import GRDB
import SwiftUI
import os.log

private enum PaginationFileIdentifierType {
    case pageid
    case title
}

// IDEA: instead of handling Strings both with pageid and title pagination,
// use tagged types (ie. SwiftTagged) as an associated type (PaginatableMediaFiles<FileIdType>?)  to differentiate and make it more obvious in all steps, without using the API type "FileIdentifierList".

@Observable class PaginatableMediaFiles {

    var status: PaginationStatus = .unknown
    let fileCachingStrategy: FileCachingStrategy
    private(set) var mediaFileInfos: [MediaFileInfo] = []
    let fullFilesFetchLimit = 10

    @ObservationIgnored
    private var canContinueRawPagination = false

    var isEmpty: Bool { status != .isPaginating && mediaFileInfos.isEmpty && !canContinueRawPagination }

    private let identifierType: PaginationFileIdentifierType

    /// may represent pageid or title depending on identifierType
    private var idsToFetch: [String]

    /// may represent pageid or title depending on identifierType
    @ObservationIgnored
    private var allIds: Set<String> = []

    @ObservationIgnored
    private var paginationTask: Task<Void, Never>?
    @ObservationIgnored
    private var observationTask: Task<Void, Never>?

    private let appDatabase: AppDatabase

    var maxCount: Int {
        allIds.count
    }

    enum FileCachingStrategy {
        case saveAll
        case replaceExisting
    }

    func replaceIDs(_ ids: [String]) {
        // FIXME: proper replace, while keeping already resolved ones
        let oldCount = idsToFetch.count
        let filteredIDs = ids.filter { !allIds.contains($0) }
        idsToFetch.append(contentsOf: filteredIDs)
        allIds.formUnion(filteredIDs)
        if filteredIDs.count > oldCount {
            status = .idle(reachedEnd: false)
            paginate()
        }
    }

    /// Initializes a Pagination model that paginates on file titles
    init(appDatabase: AppDatabase, initialTitles: [String], fileCachingStrategy: FileCachingStrategy = .replaceExisting) async throws {
        identifierType = .title
        self.idsToFetch = initialTitles
        allIds.formUnion(initialTitles)
        self.appDatabase = appDatabase
        self.fileCachingStrategy = fileCachingStrategy
        try await initialFetch()
    }

    /// Initializes a Pagination model that paginates on pageids
    init(appDatabase: AppDatabase, initialIDs: [String], fileCachingStrategy: FileCachingStrategy = .replaceExisting) async throws {
        identifierType = .pageid
        self.idsToFetch = initialIDs
        allIds.formUnion(initialIDs)
        self.appDatabase = appDatabase
        self.fileCachingStrategy = fileCachingStrategy
        try await initialFetch()
    }

    /// init for preview env not requiring to be async and can be pre-filled
    init(previewAppDatabase: AppDatabase, initialTitles: [String], mediaFileInfos: [MediaFileInfo], fileCachingStrategy: FileCachingStrategy = .replaceExisting) {
        identifierType = .title
        self.idsToFetch = initialTitles
        allIds.formUnion(initialTitles)
        self.mediaFileInfos = mediaFileInfos
        self.fileCachingStrategy = .replaceExisting
        self.appDatabase = previewAppDatabase
    }

    func fetchRawContinuePaginationItems() async throws -> (fileIdentifiers: FileIdentifierList, canContinue: Bool) {
        // NOTE: if sub-classed: this function should be overriden to provide the continue titles
        return switch identifierType {
        case .pageid: (.pageids([]), false)
        case .title: (.titles([]), false)
        }
    }

    private func observeDatabase() {

        observationTask?.cancel()
        observationTask = Task<Void, Never> {
            do {
                let ids = mediaFileInfos.map(\.id)

                let observation = ValueObservation.tracking { db in
                    try MediaFileInfo.fetchAll(ids: ids, db: db)
                }

                for try await mediaFilesFromDB in observation.values(in: appDatabase.reader) {
                    try Task.checkCancellation()
                    // NOTE: real-time re-ordering of the list is *not desired* here in this view.
                    // But we still want to get updates to the files (eg. bookmark, etc.),
                    // To achieve that and retaining the original order when this view was opened,
                    // we map the original ids to the results:

                    let goupedMediaFilesFromDB = Dictionary(grouping: mediaFilesFromDB, by: \.id)
                    // Replace network fetched item with DB-backed item if it exists there
                    self.mediaFileInfos = mediaFileInfos.map {
                        goupedMediaFilesFromDB[$0.id]?.first ?? $0
                    }
                }
            } catch {
                logger.error("Failed to observe media files \(error)")
            }
        }
    }

    func paginate() {
        guard paginationTask == nil else { return }

        if case .idle(let reachedEnd) = status, reachedEnd == true {
            logger.debug("Cannot paginate, reached the end.")
            return
        }

        status = .isPaginating
        paginationTask = Task<Void, Never> {
            defer { paginationTask = nil }

            let needsRawFilesContinue = idsToFetch.count < fullFilesFetchLimit
            do {
                /// If we reached the end of the raw item list, fetch some more with the `continue` if there are more items to paginate
                if needsRawFilesContinue, canContinueRawPagination {
                    let (fetchedIdentifiers, canContinue) = try await fetchRawContinuePaginationItems()

                    assert(
                        fetchedIdentifiers.type == self.identifierType,
                        "we expect to operate either only with pageids or only with titles"
                    )

                    // Makes sure to unique the raw files in case they come from a mixed data source
                    // to prevent list loops. This is relevant for the PaginatableCategoryMediaFiles subclass.
                    let filteredIdentifiers = fetchedIdentifiers.items.filter { !allIds.contains($0) }
                    idsToFetch.append(contentsOf: filteredIdentifiers)
                    allIds.formUnion(filteredIdentifiers)
                    self.canContinueRawPagination = canContinue
                }

                let idsToFetch = idsToFetch.popFirst(n: fullFilesFetchLimit)
                guard !idsToFetch.isEmpty else {
                    status = .idle(reachedEnd: true)
                    return
                }

                let apiIDsToFetch: FileIdentifierList =
                    switch identifierType {
                    case .pageid: .pageids(idsToFetch)
                    case .title: .titles(idsToFetch)
                    }

                let fetchedMediaFiles: [MediaFile] = try await Networking.shared.api
                    .fetchFullFileMetadata(apiIDsToFetch)
                    .map(MediaFile.init)

                switch fileCachingStrategy {
                case .saveAll:
                    try appDatabase.upsert(fetchedMediaFiles)
                case .replaceExisting:
                    // upsert newly fetched base MediaFile DB, in case it was updated,
                    // so those changes are visible when opening a file from bookmarks later
                    try appDatabase.replaceExistingMediaFiles(fetchedMediaFiles)
                }


                // Append the fetched files to our list (keeping the ItemInteraction empty as
                // we are going to observe the DB after this block and itemInteraction will be augmented from DB there.
                mediaFileInfos.append(
                    contentsOf: fetchedMediaFiles.map {
                        .init(mediaFile: $0, itemInteraction: nil)
                    })

                let reachedEnd = idsToFetch.isEmpty && !canContinueRawPagination
                status = .idle(reachedEnd: reachedEnd)

                logger.debug("new rawItems count: \(self.idsToFetch.count)")
                logger.debug("new mediaFiles count: \(self.mediaFileInfos.count)")

                // NOTE: We may already have some of the mediaFiles in the DB  (eg. isBookmarked`)
                // So to get combine the fetched info as well as live changes (eg. user changes a bookmark), we
                // observe the DB and augment `mediaFileInfos`.
                observeDatabase()

                // after the essential fetches, do an optional resolving of tags
                // this effectively caches the tags and they don't have to be network-fetched individually when opening a file.
                _ = try? await DataAccess.resolveTags(of: fetchedMediaFiles, appDatabase: appDatabase)
            } catch {
                logger.error("Failed to paginate \(error)")
                status = .error
            }
        }
    }


    private func initialFetch() async throws {
        status = .isPaginating
        let (ids, canContinue) = try await fetchRawContinuePaginationItems()
        let filteredIDs = ids.items.uniqued(on: \.self)
        idsToFetch.append(contentsOf: filteredIDs)
        allIds.formUnion(filteredIDs)
        canContinueRawPagination = canContinue
        paginate()
    }
}

extension PaginatableMediaFiles: @preconcurrency Equatable, @preconcurrency Hashable {
    static func == (lhs: PaginatableMediaFiles, rhs: PaginatableMediaFiles) -> Bool {
        lhs.mediaFileInfos == rhs.mediaFileInfos
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(mediaFileInfos)
    }
}

enum PaginationStatus: Equatable {
    case unknown
    case isPaginating
    case error
    case idle(reachedEnd: Bool)
}

extension FileIdentifierList {
    fileprivate var type: PaginationFileIdentifierType {
        switch self {
        case .titles: .title
        case .pageids: .pageid
        }
    }
}
