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

@Observable @MainActor class PaginatableMediaFiles {

    var status: PaginationStatus = .unknown
    var mediaFileInfos: [MediaFileInfo] = []
    let fullFilesFetchLimit = 10

    @ObservationIgnored
    private var canContinueRawPagination = false

    var isEmpty: Bool { status != .isPaginating && mediaFileInfos.isEmpty && !canContinueRawPagination }

    var rawTitleStack: [String]

    @ObservationIgnored
    private var paginationTask: Task<Void, Never>?
    @ObservationIgnored
    private var observationTask: Task<Void, Never>?

    private let appDatabase: AppDatabase

    @ObservationIgnored
    var fileIDs: Set<FileMetadata.ID> = []

    init(appDatabase: AppDatabase, initialTitles: [String] = []) async throws {
        self.rawTitleStack = initialTitles
        self.appDatabase = appDatabase
        try await initialFetch()
    }

    func fetchRawContinuePaginationItems() async throws -> (items: [String], canContinue: Bool) {
        // NOTE: if sub-classed: this function should be overriden to provide the continue titles
        return ([], false)
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

            let needsRawFilesContinue = rawTitleStack.count < fullFilesFetchLimit
            do {
                /// If we reached the end of the raw item list, fetch some more with the `continue` if there are more items to paginate
                if needsRawFilesContinue, canContinueRawPagination {
                    let (titles, canContinue) = try await fetchRawContinuePaginationItems()

                    // Makes sure to unique the raw files in case they come from a mixed data source
                    // to prevent list loops. This is relevant for the PaginatableCategoryFiles subclass.
                    let filteredTitles = titles.filter { !fileIDs.contains($0) }
                    rawTitleStack.append(contentsOf: filteredTitles)
                    fileIDs.formUnion(filteredTitles)

                    self.canContinueRawPagination = canContinue
                }

                let titlesToFetch = rawTitleStack.popFirst(n: fullFilesFetchLimit)
                guard !titlesToFetch.isEmpty else {
                    status = .idle(reachedEnd: true)
                    return
                }

                let fetchedMediaFiles: [MediaFile] = try await CommonsAPI.API.shared
                    .fetchFullFileMetadata(fileNames: titlesToFetch)
                    .map(MediaFile.init)

                // upsert newly fetched base MediaFile DB, in case it was updated,
                // so those changes are visible when opening a file from bookmarks later
                try appDatabase.replaceExistingMediaFiles(fetchedMediaFiles)

                // Append the fetched files to our list (keeping the ItemInteraction empty as
                // we are going to observe the DB after this block and itemInteraction will be augmented from DB there.
                mediaFileInfos.append(
                    contentsOf: fetchedMediaFiles.map {
                        .init(mediaFile: $0, itemInteraction: nil)
                    })

                // NOTE: We may already have some of the mediaFiles in the DB  (eg. isBookmarked`)
                // So to get combine the fetched info as well as live changes (eg. user changes a bookmark), we
                // observe the DB and augment `mediaFileInfos`.
                observeDatabase()

                let reachedEnd = mediaFileInfos.isEmpty && rawTitleStack.isEmpty && !canContinueRawPagination
                status = .idle(reachedEnd: reachedEnd)

                logger.debug("new rawItems count: \(self.rawTitleStack.count)")
                logger.debug("new mediaFiles count: \(self.mediaFileInfos.count)")
            } catch {
                logger.error("Failed to paginate \(error)")
                status = .error
            }
        }
    }


    private func initialFetch() async throws {
        status = .isPaginating
        let (titles, canContinue) = try await fetchRawContinuePaginationItems()
        let filteredTitles = titles.uniqued(on: \.self)
        rawTitleStack.append(contentsOf: filteredTitles)
        fileIDs.formUnion(filteredTitles)
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
