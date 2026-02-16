//
//  DataAccess.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 01.08.25.
//

import Algorithms
import CommonsAPI
import Foundation
import GRDB
import os.log

/// Provides data access functions to the API or DB
//  To be refined with more DB-first searches and fetchDate comparisons. (like `fetchCombinedTagsFromDatabaseOrAPI`)
enum DataAccess {

    /// Will cache the result and return an up-to-date CategoryInfo. (edge case: It may have a different ID as a result of a redirect)
    static func refreshCategoryInfoFromAPI(categoryInfo: CategoryInfo, appDatabase: AppDatabase) async throws -> Category? {
        var wikidataIDs: [String] = []
        var commonsCategories: [String] = []

        if let wikidataID = categoryInfo.base.wikidataId {
            wikidataIDs.append(wikidataID)
        }
        if let commonsCategory = categoryInfo.base.commonsCategory {
            commonsCategories.append(commonsCategory)
        }

        let results = try await fetchCombinedCategoriesFromDatabaseOrAPI(
            wikidataIDs: wikidataIDs,
            commonsCategories: commonsCategories,
            forceNetworkRefresh: true,
            appDatabase: appDatabase
        )

        return results.fetchedCategories.first
    }

    /// resolves categories based on commons categories and depict items (eg. from a MediaFile)
    /// Commons categories that are not linked with a wikidata item will still be returned as Categories.
    /// will return redirected (merged) items instead of original ones!
    /// Order of returned results:
    /// 1. sorted by original wikidataIDs
    /// 2. appending common categories from input, that are not linked with a wikidata item
    static func fetchCombinedCategoriesFromDatabaseOrAPI(
        wikidataIDs: [Category.WikidataID],
        commonsCategories: [String],
        forceNetworkRefresh: Bool = false,
        appDatabase: AppDatabase
    ) async throws -> CategoryFetchResult {
        let cachedCategories: [Category]

        if forceNetworkRefresh {
            cachedCategories = []
        } else {
            cachedCategories = (try? appDatabase.fetchCategoryInfos(wikidataIDs: wikidataIDs, resolveRedirections: true))?.compactMap(\.base) ?? []
        }

        let cachedIDs = cachedCategories.compactMap(\.wikidataId)
        let missingIDs = Set(wikidataIDs).subtracting(cachedIDs)

        let fetchResult = try await fetchWikidataBackedCategoriesFromAPI(
            wikidataIDs: Array(missingIDs),
            commonsCategories: commonsCategories,
            // if we refresh from network, we want to cache the results
            shouldCache: forceNetworkRefresh,
            appDatabase: appDatabase
        )

        let fetchedAndCachedCombined = cachedCategories + fetchResult.fetchedCategories
        let groupedByWikidataID = fetchedAndCachedCombined.grouped(by: \.wikidataId)
        let groupedByCommonsCategory = fetchedAndCachedCombined.grouped(by: \.commonsCategory)

        let sortedByWikidataID: [Category] = wikidataIDs.compactMap { id in
            let redirectID = fetchResult.redirectedIDs[id]
            return if let category = groupedByWikidataID[id]?.first ?? groupedByWikidataID[redirectID]?.first {
                category
            } else {
                nil
            }
        }

        let sortedByCommonsCategory: [Category] = commonsCategories.compactMap { commonsCategory in
            return if let category = groupedByCommonsCategory[commonsCategory]?.first {
                category
            } else {
                nil
            }
        }

        // Commons categories without a linked wikidata item
        let sortedPureCommonsCategories: [Category] =
            commonsCategories
            .filter { groupedByCommonsCategory[$0] == nil }
            .map { Category(commonsCategory: $0) }

        let resultCategories = (sortedByWikidataID + sortedByCommonsCategory + sortedPureCommonsCategories)
            .uniqued(on: { $0.wikidataId ?? $0.commonsCategory })

        return .init(
            fetchedCategories: resultCategories,
            redirectedIDs: fetchResult.redirectedIDs
        )
    }


    struct CategoryFetchResult {
        let fetchedCategories: [Category]
        let redirectedIDs: [Category.WikidataID: Category.WikidataID]
    }

    // Only returns Categories that have a WikidataID
    private static func fetchWikidataBackedCategoriesFromAPI(
        wikidataIDs: [String],
        commonsCategories: [String],
        shouldCache: Bool,
        appDatabase: AppDatabase
    ) async throws -> CategoryFetchResult {

        let languageCode = Locale.current.wikiLanguageCodeIdentifier


        // TODO: parallelize with taskGroup?


        async let resolvedWikiItemsTask = Networking.shared.api
            .fetchGenericWikidataItems(itemIDs: wikidataIDs, languageCode: languageCode)

        /// categories often have associated wikidataItems( & vice-versa, see above), resolve wiki items for the found categories:
        async let resolvedCategoryItemsTask = Networking.shared.api
            .findWikidataItemsForCategories(commonsCategories, languageCode: languageCode)

        let (resolvedWikiItems, resolvedCategoryItems) = try await (resolvedWikiItemsTask, resolvedCategoryItemsTask)

        let combinedWikidataItems = (resolvedWikiItems + resolvedCategoryItems).uniqued(on: \.id)

        let labelsAndRedirects = try await fetchWikidataLabelsAndRedirects(
            wikidataIDs: combinedWikidataItems.map(\.id),
            languageCode: languageCode
        )

        // Since both API endpoints/task return different subsets of data
        // we merge the fields here
        let mergedItems: [Category] = combinedWikidataItems.compactMap { apiItem in
            /// If we encounter a redirect, initialize an empty Category that only has a redirect ID
            /// so that it can be resolved separately
            if let redirectID = labelsAndRedirects[apiItem.id]?.redirectsToId {
                return .init(wikidataID: apiItem.id, redirectsTo: redirectID)
            } else {
                var item = Category(apiItem: apiItem)
                if let actionAPIResult = labelsAndRedirects[apiItem.id] {
                    item.label = actionAPIResult.label ?? item.label
                    item.description = actionAPIResult.description ?? item.description
                }
                return item
            }
        }

        /// NOTE: resolveRedirections recursively calls this function (fetchAndCacheCategory)
        /// We still save the barebone redirect-Categories
        /// to be able to get the redirected item quickly, without always fetching from network.
        let redirectResult = try await resolveRedirectionsFromAPI(
            consume mergedItems,
            shouldCache: shouldCache,
            appDatabase: appDatabase
        )

        if shouldCache {
            let insertedCategories = try appDatabase.upsert(
                redirectResult.fetchedCategories,
                handleRedirections: redirectResult.redirectedIDs
            )
            return .init(fetchedCategories: insertedCategories, redirectedIDs: redirectResult.redirectedIDs)

        } else {
            return redirectResult
        }
    }

    private static func fetchWikidataLabelsAndRedirects(wikidataIDs: [String], languageCode: LanguageCode) async throws -> [String: GenericWikidataItem] {
        let apiFetchLimit = 50
        let chunkedIDs = wikidataIDs.chunks(ofCount: apiFetchLimit)
        var result: [String: GenericWikidataItem] = [:]

        for ids in chunkedIDs {
            do {
                let ids = Array(ids)
                let fetchedResult = try await Networking.shared.api
                    .fetchWikidataEntities(ids: ids, preferredLanguages: [languageCode])

                result.merge(fetchedResult) { current, new in
                    if current == new {
                        assertionFailure("Duplicates from api")
                    }
                    return current
                }

            }
        }

        return result
    }

    /// For all argument items that contain a redirection, fetch the item that should be redirected from the network
    /// returned list **preserves the original order**
    private static func resolveRedirectionsFromAPI(_ items: [Category], shouldCache: Bool, appDatabase: AppDatabase) async throws -> CategoryFetchResult {
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

        let fetchedRedirectionResult = try await fetchWikidataBackedCategoriesFromAPI(
            wikidataIDs: redirections.map(\.to),
            commonsCategories: [],
            shouldCache: shouldCache,
            appDatabase: appDatabase
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
