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
    static func refreshCategoryInfoFromAPI(categoryInfo: CategoryInfo, appDatabase: AppDatabase) async throws -> CategoryInfo? {
        guard let wikidataID = categoryInfo.base.wikidataId else {
            logger.debug("Category \(categoryInfo.base.label ?? categoryInfo.base.commonsCategory ?? "unknown?") has no wikidata ID, cannot refresh.")
            // TODO: consider what it would mean to refresh a commonsCategory-only `Category`
            return nil
        }
        let refreshedCategory = try await fetchCategoriesFromAPI(
            wikidataIDs: [wikidataID],
            shouldCache: true,
            appDatabase: appDatabase
        )
        .fetchedCategories
        .first

        guard let dbID = refreshedCategory?.id else {
            assertionFailure("We expect the returned item to be saved in the DB, because `shouldCache: true` (thus having an ID)")
            return nil
        }

        return try await appDatabase.reader.read { db in
            return try Category.filter(id: dbID)
                .including(required: Category.itemInteraction)
                .asRequest(of: CategoryInfo.self)
                .fetchOne(db)
        }
    }

    /// resolves Tags based on commons categories and depict items (eg. from a MediaFile)
    /// will return redirected (merged) items instead of original ones!
    static func fetchCombinedTagsFromDatabaseOrAPI(
        wikidataIDs: [Category.WikidataID],
        commonsCategories: [String],
        forceNetworkRefresh: Bool = false,
        appDatabase: AppDatabase
    ) async throws -> [TagItem] {
        let cachedCategoryInfos: [CategoryInfo] =
            if forceNetworkRefresh {
                []
            } else {
                (try? appDatabase.fetchCategoryInfos(wikidataIDs: wikidataIDs, resolveRedirections: true)) ?? []
            }

        let cachedIDs = cachedCategoryInfos.compactMap(\.base.wikidataId)
        let missingIDs = Set(wikidataIDs).subtracting(cachedIDs)

        let fetchResult = try await fetchCategoriesFromAPI(
            wikidataIDs: Array(missingIDs),
            // if we refresh from network, we want to cache the results
            shouldCache: forceNetworkRefresh,
            appDatabase: appDatabase
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
    static func fetchCategoriesFromAPI(wikidataIDs: [String], shouldCache: Bool, appDatabase: AppDatabase) async throws -> CategoryFetchResult {

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
                    /// If we encounter a redirect, initialize an empty Category that only has a redirect ID
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
        /// We still save the barebone redirect-Categories
        /// to be able to get the redirected item quickly, without always fetching from network.
        let redirectResult = try await resolveRedirectionsFromAPI(
            consume fetchedCategories,
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

        let fetchedRedirectionResult = try await fetchCategoriesFromAPI(
            wikidataIDs: redirections.map(\.to),
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
