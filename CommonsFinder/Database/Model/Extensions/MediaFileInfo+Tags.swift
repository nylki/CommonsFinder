//
//  MediaFileInfo+Tags.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 20.04.25.
//

import Algorithms
import CommonsAPI
import Foundation
import os.log

// TODO: move the API calls to am enum namespace handling only API request
// do only import CommonsAPI there for easier testing and maintainability

extension MediaFile {

    /// resolves Tags based on commons categories and depict items in MediaFile
    /// will return redirected (merged) items instead of original ones!
    @MainActor
    func resolveTags(appDatabase: AppDatabase) async throws -> [TagItem] {

        let depictWikdataIDs: [String] =
            statements
            .filter(\.isDepicts)
            .compactMap(\.mainItem?.id)


        let cachedCategoryInfos = (try? appDatabase.fetchCategoryInfos(wikidataIDs: depictWikdataIDs)) ?? []
        let cachedIDs = cachedCategoryInfos.compactMap(\.base.wikidataId)
        let missingIDs = Set(depictWikdataIDs).subtracting(cachedIDs)

        let fetchedMissingCategoryInfos: [CategoryInfo] = try await fetchAndCacheCategoryFromAPI(
            appDatabase: appDatabase,
            wikidataIDs: Array(missingIDs)
        )
        .map { .init($0) }

        logger.info("fetchedMissingCategoryInfos: \(fetchedMissingCategoryInfos.debugDescription)")


        let groupedWikidataCategories = Set(consume cachedCategoryInfos + consume fetchedMissingCategoryInfos).grouped(by: \.base.wikidataId)

        // Make sure to continue with results in the original order
        let combinedCategories = depictWikdataIDs.compactMap { wikidataID in
            groupedWikidataCategories[wikidataID]?.first?.base
        }


        /// NOTE: resolveRedirections recursively calls this function (fetchAndCacheCategory)
        /// We still save items that have been merged into another as thin Categories with a redirection id
        /// to be able to get the redirected item quickly, without always fetching from network.
        let redirectionResolvedCategories = try await resolveRedirectionsFromAPI(
            consume combinedCategories,
            appDatabase: appDatabase
        )


        let depictionTags: [TagItem] =
            redirectionResolvedCategories
            .compactMap { category in
                var usages: Set<TagType> = [.depict]
                if let categoryName = category.commonsCategory, categories.contains(categoryName) {
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
            categories
            .filter { !categoriesWithDepiction.contains($0) }
            .map { category in
                .init(Category(commonsCategory: category), pickedUsages: [.category])
            }

        return depictionTags + pureCategoryTags
    }

    private func fetchAndCacheCategoryFromAPI(appDatabase: AppDatabase, wikidataIDs: [String]) async throws -> [Category] {

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

        try appDatabase.upsert(fetchedCategories)
        return fetchedCategories
    }

    /// For all argument items that contain a redirection, fetch the item that should be redirected from the network
    /// **preserves the original order**
    private func resolveRedirectionsFromAPI(_ items: [Category], appDatabase: AppDatabase) async throws -> [Category] {
        let toFromDict: [(to: Category.WikidataID, from: Category.WikidataID)] =
            items
            .compactMap {
                if let from = $0.wikidataId, let to = $0.redirectToWikidataId {
                    (to: to, from: from)
                } else {
                    nil
                }
            }

        guard !toFromDict.isEmpty else { return items }

        let idsToFetch = toFromDict.map(\.to)

        let fetchedRedirectionItems = try await fetchAndCacheCategoryFromAPI(
            appDatabase: appDatabase,
            wikidataIDs: idsToFetch
        )

        let groupedRedirectionItems =
            fetchedRedirectionItems
            .grouped(by: \.wikidataId)

        return items.compactMap { item in
            if let toID = item.redirectToWikidataId,
                let redirectionItem = groupedRedirectionItems[toID]?.first
            {
                redirectionItem
            } else {
                item
            }
        }
    }
}
