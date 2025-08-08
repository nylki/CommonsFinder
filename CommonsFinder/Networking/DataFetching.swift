//
//  DataFetching.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 01.08.25.
//

import Algorithms
import CommonsAPI
import Foundation
import os.log

enum DataFetching {

    static func fetchCategoryFromNetwork(category: Category, appDatabase: AppDatabase) async throws -> Category? {
        guard let wikidataId = category.wikidataId else { return nil }

        let fetchedItem = try await fetchAndCacheCategoryFromAPI(
            appDatabase: appDatabase,
            wikidataIDs: [wikidataId]
        )
        .fetchedCategories
        .first

        guard let fetchedItem else { return nil }

        return fetchedItem
    }

    /// resolves Tags based on commons categories and depict items (eg. from a MediaFile)
    /// will return redirected (merged) items instead of original ones!
    static func fetchCombinedTags(
        wikidataIDs: [Category.WikidataID],
        commonsCategories: [String],
        forceNetworkRefresh: Bool = false,
        appDatabase: AppDatabase
    ) async throws -> [TagItem] {
        let cachedCategoryInfos: [CategoryInfo] =
            if forceNetworkRefresh {
                []
            } else {
                (try? appDatabase.fetchCategoryInfos(wikidataIDs: wikidataIDs)) ?? []
            }

        let cachedIDs = cachedCategoryInfos.compactMap(\.base.wikidataId)
        let missingIDs = Set(wikidataIDs).subtracting(cachedIDs)

        let fetchResult = try await fetchAndCacheCategoryFromAPI(
            appDatabase: appDatabase,
            wikidataIDs: Array(missingIDs)
        )

        let fetchedCategoryInfos: [CategoryInfo] = fetchResult.fetchedCategories.map { .init($0) }

        let groupedWikidataCategories = Set(consume cachedCategoryInfos + consume fetchedCategoryInfos).grouped(by: \.base.wikidataId)

        // Make sure to continue with results in the original order
        let orderedIDs = wikidataIDs.map { fetchResult.redirectedIDs[$0] ?? $0 }
        let depictionTags: [TagItem] =
            orderedIDs
            .compactMap { wikidataID in
                guard let category = groupedWikidataCategories[wikidataID]?.first?.base else {
                    return nil
                }
                var usages: Set<TagType> = [.depict]
                if let categoryName = category.commonsCategory, commonsCategories.contains(categoryName) {
                    usages.insert(.category)
                }
                return TagItem(category, pickedUsages: usages)
            }

        let categoriesWithDepiction: [String] =
            depictionTags
            .filter { $0.pickedUsages.contains(.category) }
            .compactMap { depictItem in
                depictItem.baseItem.commonsCategory
            }


        let pureCategoryTags: [TagItem] =
            commonsCategories
            .filter { !categoriesWithDepiction.contains($0) }
            .map { category in
                .init(Category(commonsCategory: category), pickedUsages: [.category])
            }

        return depictionTags + pureCategoryTags
    }


    struct CategoryFetchResult {
        let fetchedCategories: [Category]
        let redirectedIDs: [Category.WikidataID: Category.WikidataID]
    }
    private static func fetchAndCacheCategoryFromAPI(appDatabase: AppDatabase, wikidataIDs: [String]) async throws -> CategoryFetchResult {

        let apiFetchLimit = 50
        let chunkedIDs = wikidataIDs.chunks(ofCount: apiFetchLimit)

        var fetchedCategories: [Category] = []
        // TODO: parallelize with taskGroup?
        for ids in chunkedIDs {
            do {
                let ids = Array(ids)
                let languageCode = Locale.current.wikiLanguageCodeIdentifier


                // TODO: MAYBE! fetch claims (for commmonsCategory, length, etc.) in wbgetentities directly
                // but may be less efficient in the end, because the returned json is much bigger
                // than performing two queries like this?
                // FIXME: Otherwise: better define different return types to not expect fields
                // that are not filled from one API (eg. redirects) !

                async let wikiItemsTask = API.shared
                    .fetchGenericWikidataItems(itemIDs: ids, languageCode: languageCode)

                async let actionAPITask = API.shared
                    .fetchWikidataEntities(ids: ids, preferredLanguages: [languageCode])

                let (wikiItems, actionAPIResults) = try await (wikiItemsTask, actionAPITask)

                // Since both API endpoints/task return different subsets of data
                // we merge the fields here
                let mergedItems: [Category] = wikiItems.compactMap { apiItem in
                    /// If we encounter a redirect, initialize an otherwise empty Category that has a redirect ID
                    /// so that it can be resolved separately
                    if let redirectID = actionAPIResults[apiItem.id]?.redirectsToId {
                        return .init(wikidataID: apiItem.id, redirectsTo: redirectID)
                    } else {
                        var item = Category(apiItem: apiItem)
                        if let actionAPIResult = actionAPIResults[apiItem.id] {
                            item.label = actionAPIResult.label ?? item.label
                            item.description = actionAPIResult.description ?? item.description
                        }
                        return item
                    }
                }

                fetchedCategories.append(contentsOf: mergedItems)
            }
        }

        /// NOTE: resolveRedirections recursively calls this function (fetchAndCacheCategory)
        /// We still save items that have been merged into another as thin Categories with a redirection id
        /// to be able to get the redirected item quickly, without always fetching from network.
        let redirectResult = try await resolveRedirectionsFromAPI(
            fetchedCategories,
            appDatabase: appDatabase
        )

        // FIXME: rewrite bookmarks to redirected categories
        try appDatabase.upsert(fetchedCategories)

        try appDatabase.upsert(redirectResult.fetchedCategories)

        return redirectResult
    }

    /// For all argument items that contain a redirection, fetch the item that should be redirected from the network
    /// returned list **preserves the original order**
    private static func resolveRedirectionsFromAPI(_ items: [Category], appDatabase: AppDatabase) async throws -> CategoryFetchResult {
        let redirections: [(to: Category.WikidataID, from: Category.WikidataID)] =
            items.compactMap {
                if let from = $0.wikidataId,
                    let to = $0.redirectToWikidataId
                {
                    (to: to, from: from)
                } else {
                    nil
                }
            }

        guard !redirections.isEmpty else {
            // no redictions found in given item, return original list
            return .init(fetchedCategories: items, redirectedIDs: [:])
        }

        let fetchedRedirectionResult = try await fetchAndCacheCategoryFromAPI(
            appDatabase: appDatabase,
            wikidataIDs: redirections.map(\.to)
        )

        let groupedRedirectionItems = fetchedRedirectionResult
            .fetchedCategories
            .grouped(by: \.wikidataId)

        var resultRedirections: [Category.WikidataID: Category.WikidataID] = [:]

        let resultItems = items.compactMap { item in
            if let toID = item.redirectToWikidataId,
                let fromID = item.wikidataId,
                let redirectionItem = groupedRedirectionItems[toID]?.first
            {
                resultRedirections[fromID] = toID
                return redirectionItem
            } else {
                return item
            }
        }

        return .init(fetchedCategories: resultItems, redirectedIDs: resultRedirections)
    }
}
