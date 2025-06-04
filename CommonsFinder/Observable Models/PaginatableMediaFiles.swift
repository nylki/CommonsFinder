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

    var status: Status = .unknown
    var mediaFileInfos: [MediaFileInfo] = []
    let fullFilesFetchLimit = 10

    @ObservationIgnored
    private var canContinueRawPagination = false

    var isEmpty: Bool { rawTitles.isEmpty }

    var rawTitles: [String]

    @ObservationIgnored
    private var paginationTask: Task<Void, Never>?
    private let appDatabase: AppDatabase

    @ObservationIgnored
    var fileIDs: Set<FileMetadata.ID> = []

    init(appDatabase: AppDatabase, initialTitles: [String] = []) async throws {
        self.rawTitles = initialTitles
        self.appDatabase = appDatabase
        try await initialFetch()
    }

    func fetchRawContinuePaginationItems() async throws -> (items: [String], canContinue: Bool) {
        // NOTE: if sub-classed: this function should be overriden to provide the continue titles
        return ([], false)
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

            let needsRawFilesContinue = (mediaFileInfos.count + fullFilesFetchLimit) >= rawTitles.count
            do {
                /// If we reached the end of the raw item list, fetch some more with the `continue` if there are more items to paginate
                if needsRawFilesContinue, canContinueRawPagination {
                    let (titles, canContinue) = try await fetchRawContinuePaginationItems()

                    // Makes sure to unique the raw files in case they come from a mixed data source
                    // to prevent list loops. This is relevant for the PaginatableWikiCategoryFiles subclass.
                    let filteredTitles = titles.filter { !fileIDs.contains($0) }
                    rawTitles.append(contentsOf: filteredTitles)
                    fileIDs.formUnion(filteredTitles)

                    self.canContinueRawPagination = canContinue
                }

                let startIdx = mediaFileInfos.count
                let endIdx = min(rawTitles.count, mediaFileInfos.count + fullFilesFetchLimit)

                let titlesToFetch = Array(rawTitles[startIdx..<endIdx])
                guard !titlesToFetch.isEmpty else {
                    status = .idle(reachedEnd: mediaFileInfos.count == rawTitles.count)
                    return
                }

                let fetchedItems = try await CommonsAPI.API.shared
                    .fetchFullFileMetadata(fileNames: titlesToFetch)
                    .map(MediaFile.init)

                let ids = fetchedItems.map(\.id)

                // here we augment (online) fetched files with user metadata from DB
                // if they have been used/opened before.
                let userMetadata = try await appDatabase.reader
                    .read { db in
                        try ItemInteraction
                            .filter(ids.contains(ItemInteraction.Columns.mediaFileId))
                            .fetchAll(db)
                    }
                    .grouped(by: \.id)

                let fetchedMediaFileInfos: [MediaFileInfo] = fetchedItems.map { mediaFile in
                    .init(
                        mediaFile: mediaFile,
                        itemInteraction: userMetadata[mediaFile.id]?.first
                    )
                }

                mediaFileInfos.append(contentsOf: fetchedMediaFileInfos)

                status = .idle(reachedEnd: mediaFileInfos.count == rawTitles.count)

                logger.debug("new rawItems count: \(self.rawTitles.count)")
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
        rawTitles.append(contentsOf: filteredTitles)
        fileIDs.formUnion(filteredTitles)
        canContinueRawPagination = canContinue
        paginate()
    }
}

extension PaginatableMediaFiles {
    enum Status: Equatable {
        case unknown
        case isPaginating
        case error
        case idle(reachedEnd: Bool)
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
