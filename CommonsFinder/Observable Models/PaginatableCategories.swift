//
//  PaginatableCategories.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 27.03.26.
//

import GRDB
import SwiftUI
import os.log

struct CategorySearchTargets: OptionSet {
    let rawValue: Int
    static let wikidata = Self(rawValue: 1 << 0)
    static let commons = Self(rawValue: 1 << 1)

    static var all: Self {
        [.wikidata, .commons]
    }
}

@Observable class PaginatableCategories {
    var status: PaginationStatus = .unknown
    let searchTargets: CategorySearchTargets

    // the raw ids/categories are FIFO and will be removed when fetching the full Category.
    var rawWikidataIDs: [String] = []
    var rawCommonsCategories: [String] = []
    var rawCount: Int { rawWikidataIDs.count + rawCommonsCategories.count }

    /// the combined commons categories + wikidata items
    var categoryInfos: [CategoryInfo] = []

    private let paginateFetchLimit = 10

    @ObservationIgnored
    private var canContinueWikidataPagination = false
    @ObservationIgnored
    private var canContinueCommonsPagination = false

    @ObservationIgnored
    private var paginationTask: Task<Void, Never>?
    @ObservationIgnored
    private var observationTask: Task<Void, Never>?

    private let appDatabase: AppDatabase

    @ObservationIgnored
    var allWikidataIdSet: Set<Category.WikidataID> = []
    @ObservationIgnored
    var allCommonsCategoriesSet: Set<String> = []

    var isEmpty: Bool {
        allCommonsCategoriesSet.isEmpty && allWikidataIdSet.isEmpty
    }

    init(appDatabase: AppDatabase, searchTargets: CategorySearchTargets) {
        self.searchTargets = searchTargets
        self.appDatabase = appDatabase
    }

    init(previewAppDatabase: AppDatabase, searchTargets: CategorySearchTargets, prefilledCategories: [CategoryInfo]) {
        self.searchTargets = searchTargets
        self.appDatabase = previewAppDatabase
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
                            try await performRawWikidataPagination()
                        }
                    } catch {
                        logger.error("Failed to fetch raw wikidata items for pagination \(error)")
                    }
                }

                let needsRawCommonsPagination = rawCommonsCategories.count < paginateFetchLimit && canContinueCommonsPagination
                async let rawCommonsTask = Task<Void, Never> {
                    do {
                        if needsRawCommonsPagination {
                            try await performRawCommonsCategoryPagination()
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


                let fetchedCategories: [CategoryInfo] =
                    try await DataAccess.fetchCombinedCategoriesFromDatabaseOrAPI(
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

    func rawWikidataPagination() async throws -> (ids: [String], canContinue: Bool) {
        // NOTE: if sub-classed: this function should be overriden to provide the continue item
        return (ids: [], canContinue: false)
    }


    func rawCommonsCategoryPagination() async throws -> (categories: [String], canContinue: Bool) {
        // NOTE: if sub-classed: this function should be overriden to provide the continue items
        return (categories: [], canContinue: false)
    }

    func performRawCommonsCategoryPagination() async throws {
        guard searchTargets.contains(.commons) else { return }
        let result = try await rawCommonsCategoryPagination()
        let categories = result.categories.filter { !allCommonsCategoriesSet.contains($0) }

        rawCommonsCategories.append(contentsOf: categories)
        allCommonsCategoriesSet.formUnion(categories)
        canContinueCommonsPagination = result.canContinue
    }

    func performRawWikidataPagination() async throws {
        guard searchTargets.contains(.wikidata) else { return }
        let result = try await rawWikidataPagination()
        let wikidataIDs = result.ids.filter { !allWikidataIdSet.contains($0) }

        rawWikidataIDs.append(contentsOf: wikidataIDs)
        allWikidataIdSet.formUnion(wikidataIDs)
        canContinueWikidataPagination = result.canContinue
    }

    func initialFetch() async throws {
        status = .isPaginating
        async let rawWikidataTask: () = performRawWikidataPagination()
        async let rawCommonsTask: () = performRawCommonsCategoryPagination()
        do {
            let (_, _) = try await (rawWikidataTask, rawCommonsTask)

            logger.info("raw wikidata ids: \(self.rawWikidataIDs)")
            logger.info("raw commons categories: \(self.rawCommonsCategories)")
        } catch {
            logger.error("Failed to perform initial raw fetch search categories: \(error)")
        }
        paginate()
    }
}
