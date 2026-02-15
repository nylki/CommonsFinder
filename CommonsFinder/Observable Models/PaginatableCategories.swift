//
//  PaginatableCategories.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 25.08.25.
//

import Algorithms
import CommonsAPI
import Foundation
import GRDB
import os.log

/// Since This is a specialized pagination model for Category searches
/// where commons category searches and wikidata searches are combines into an interleaving pagination
@Observable class PaginatableCategorySearch {
    let searchString: String
    var status: PaginationStatus = .unknown
    let sort: SearchOrder

    private var commonsOffset: Int?
    private var wikidataOffset: Int?

    // the raw ids/categories are FIFO and will be removed when fetching the full Category.
    private var rawWikidataIDs: [String] = []
    private var rawCommonsCategories: [String] = []
    var rawCount: Int { rawWikidataIDs.count + rawCommonsCategories.count }

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

    init(previewAppDatabase: AppDatabase, searchString: String, prefilledCategories: [CategoryInfo]) {
        self.appDatabase = previewAppDatabase
        self.sort = .relevance
        self.searchString = searchString
        self.categoryInfos = prefilledCategories
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

                // Only continue if there is anything to fetch at all
                guard !wikidataIDsToFetchs.isEmpty || !commonsCategoriesToFetch.isEmpty else {
                    status = .idle(reachedEnd: true)
                    return
                }


                let fetchedCategories: [CategoryInfo] = try await DataAccess.fetchCombinedCategoriesFromDatabaseOrAPI(
                    wikidataIDs: wikidataIDsToFetchs,
                    commonsCategories: commonsCategoriesToFetch,
                    appDatabase: appDatabase
                )
                .fetchedCategories
                .map { .init($0) }
            
                

                // TODO: zip order?

                categoryInfos += fetchedCategories
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
        let result = try await Networking.shared.api.searchWikidataItems(
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
        let result = try await Networking.shared.api.searchCategories(
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
        async let rawWikidataTask: () = rawWikidataPagination()
        async let rawCommonsTask: () = rawCommonsCategoryPagination()
        do {
            let (_, _) = try await (rawWikidataTask, rawCommonsTask)
            logger.info("raw wikidata ids: \(self.rawWikidataIDs)")
            logger.info("raw commons categories: \(self.rawCommonsCategories)")
        } catch {
            logger.error("Failed to perform initial raw fetch search categories for \(self.searchString): \(error)")
        }
        paginate()
    }
}
