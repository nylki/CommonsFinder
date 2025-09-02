//
//  PaginatableCategories.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 25.08.25.
//

import Algorithms
import Collections
import CommonsAPI
import Foundation
import GRDB
import os.log

/// Since This is a specialized pagination model for Category searches
/// where commons category searches and wikidata searches are combines into an interleaving pagination
@Observable @MainActor class PaginatableCategorySearch {
    let searchString: String
    var status: PaginationStatus = .unknown
    let sort: SearchOrder

    private var commonsOffset: Int?
    private var wikidataOffset: Int?

    // the raw ids/categories are FIFO and will be removed when fetching the full Category.
    private var rawWikidataIDs: [String] = []
    private var rawCommonsCategories: [String] = []
    private var rawCount: Int { rawWikidataIDs.count + rawCommonsCategories.count }

    /// the combined commons categories + wikidata items
    var categoryInfos: [CategoryInfo] = []

    private let paginateFetchLimit = 10

    @ObservationIgnored
    private var canContinueWikidataPagination = false
    @ObservationIgnored
    private var canContinueCommonsPagination = false

    var isEmpty: Bool { rawWikidataIDs.isEmpty && rawCommonsCategories.isEmpty }

    @ObservationIgnored
    private var paginationTask: Task<Void, Never>?
    @ObservationIgnored
    private var observationTask: Task<Void, Never>?

    private let appDatabase: AppDatabase

    @ObservationIgnored
    var wikidataIdSet: Set<Category.WikidataID> = []
    @ObservationIgnored
    var commonsCategoriesSet: Set<String> = []

    init(appDatabase: AppDatabase, searchString: String, sort: SearchOrder) async throws {
        self.appDatabase = appDatabase
        self.searchString = searchString
        self.sort = sort
        try await initialFetch()
    }

    private func observeDatabase() {
        observationTask?.cancel()
        observationTask = Task<Void, Never> {
            do {
                let categories = categoryInfos.map(\.base)
                let observation = ValueObservation.tracking { db in
                    try Category
                        .filter(basedOn: categories)
                        .including(optional: Category.itemInteraction)
                        .asRequest(of: CategoryInfo.self)
                        .fetchAll(db)
                }

                for try await categoriesFromDB in observation.values(in: appDatabase.reader) {
                    try Task.checkCancellation()
                    let groupedCategoriesFromDB = Dictionary(grouping: categoriesFromDB, by: \.id)
                    // Replace network fetched items with DB-backed item (having interactions) if it exists there:
                    self.categoryInfos = categoryInfos.map {
                        groupedCategoriesFromDB[$0.id]?.first ?? $0
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

            do {
                /// If we reached the end of the raw item list
                /// fetch from both wikidata and commons search via their respective `continue` values to paginate

                let needsRawWikidataPagination = rawWikidataIDs.count < paginateFetchLimit && canContinueWikidataPagination
                async let rawWikidataTask = Task<Void, Never> {
                    do {
                        if needsRawWikidataPagination {
                            try await rawWikidataPagination()
                        }
                    } catch {
                        logger.error("Failed to fetch raw wikidata items for pagination \(error)")
                    }
                }

                let needsRawCommonsPagination = rawCommonsCategories.count < paginateFetchLimit && canContinueWikidataPagination
                async let rawCommonsTask = Task<Void, Never> {
                    do {
                        if needsRawCommonsPagination {
                            try await rawCommonsCategoryPagination()
                        }
                    } catch {
                        logger.error("Failed to fetch raw commons categories for pagination \(error)")
                    }
                }

                let (_, _) = await (rawWikidataTask.value, rawCommonsTask.value)

                let commonsCategoriesToFetch = rawCommonsCategories.popFirst(n: paginateFetchLimit)
                let wikidataIDsToFetchs = rawWikidataIDs.popFirst(n: paginateFetchLimit)

                guard !commonsCategoriesToFetch.isEmpty || !wikidataIDsToFetchs.isEmpty else {
                    status = .idle(reachedEnd: true)
                    return
                }

                let wikidataIDsForCategories = try await CommonsAPI.API.shared
                    .findWikidataItemsForCategories(commonsCategoriesToFetch, languageCode: Locale.current.wikiLanguageCodeIdentifier)
                    .map(\.id)

                // Here we fetch from both wikidataIDs and commons categories
                let idsToFetch = Array((wikidataIDsToFetchs + wikidataIDsForCategories).uniqued())
                guard !idsToFetch.isEmpty else {
                    status = .idle(reachedEnd: true)
                    return
                }

                let result = try await DataAccess.fetchCategoriesFromAPI(
                    wikidataIDs: idsToFetch,
                    shouldCache: false,
                    appDatabase: appDatabase
                )

                let categoriesAlreadyHandled = Set(result.fetchedCategories.compactMap(\.commonsCategory))

                let pureCommonCategories =
                    commonsCategoriesToFetch
                    .filter { !categoriesAlreadyHandled.contains($0) }
                    .map { Category(commonsCategory: $0) }


                let combinedResult: [CategoryInfo] =
                    zippedFlatMap(result.fetchedCategories, pureCommonCategories)
                    .uniqued { ($0.wikidataId ?? $0.commonsCategory) }
                    .map { CategoryInfo($0) }

                // Append the fetched Categories to our list (keeping the ItemInteraction empty as
                // we are going to observe the DB after this block and itemInteraction will be augmented from DB there.

                categoryInfos = (categoryInfos + combinedResult).uniqued { ($0.base.wikidataId ?? $0.base.commonsCategory) }

                // upsert newly fetched base MediaFile DB, in case it was updated,
                // so those changes are visible when opening a file from bookmarks later
                //                try appDatabase.replaceExistingMediaFiles(fetchedCategories)

                // Append the fetched files to our list (keeping the ItemInteraction empty as
                // we are going to observe the DB after this block and itemInteraction will be augmented from DB there.


                // NOTE: We may already have some of the mediaFiles in the DB  (eg. isBookmarked`)
                // So to get combine the fetched info as well as live changes (eg. user changes a bookmark), we
                // observe the DB and augment `mediaFileInfos`.
                // TODO:
                observeDatabase()

                status = .idle(
                    reachedEnd: categoryInfos.isEmpty && rawWikidataIDs.isEmpty && rawCommonsCategories.isEmpty && canContinueCommonsPagination == false && canContinueWikidataPagination == false)

                logger.debug("new rawCommonsCategories count: \(self.rawCommonsCategories)")
                logger.debug("new rawWikidataIDs count: \(self.rawWikidataIDs.count)")
                logger.debug("new category count: \(self.categoryInfos.count)")
            } catch {
                logger.error("Failed to paginate \(error)")
                status = .error
            }
        }
    }

    private func rawWikidataPagination() async throws {
        let result = try await CommonsAPI.API.shared.searchWikidataItems(
            term: searchString,
            languageCode: Locale.current.wikiLanguageCodeIdentifier,
            offset: wikidataOffset
        )

        let fetchedWikidataIDs = result.search
            .map(\.id)
            .filter { !wikidataIdSet.contains($0) }

        wikidataOffset = result.searchContinue
        rawWikidataIDs.append(contentsOf: fetchedWikidataIDs)
        wikidataIdSet.formUnion(fetchedWikidataIDs)
        canContinueWikidataPagination = wikidataOffset != nil
    }


    private func rawCommonsCategoryPagination() async throws {
        let result = try await CommonsAPI.API.shared.searchCategories(
            for: searchString,
            sort: sort.apiType,
            limit: .max,
            offset: commonsOffset
        )
        let categoriesWithoutPrefix = result.items
            .map {
                String($0.title.split(separator: "Category:")[0])
            }
            .filter { !commonsCategoriesSet.contains($0) }

        rawCommonsCategories.append(contentsOf: categoriesWithoutPrefix)
        commonsCategoriesSet.formUnion(categoriesWithoutPrefix)
        commonsOffset = result.offset
        canContinueCommonsPagination = commonsOffset != nil
    }


    private func initialFetch() async throws {
        status = .isPaginating
        try await rawWikidataPagination()
        try await rawCommonsCategoryPagination()
        paginate()
    }

}
