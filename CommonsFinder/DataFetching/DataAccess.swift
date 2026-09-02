//
//  DataAccess.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 01.08.25.
//

import Algorithms
import CommonsAPI
import CoreLocation
import Foundation
import GRDB
import RegexBuilder
import os.log

typealias ScoredCategoryInfo = (score: Double, categoryInfo: CategoryInfo)

/// Provides data access functions to the API or DB
//  To be refined with more DB-first searches and fetchDate comparisons. (like `fetchCombinedTagsFromDatabaseOrAPI`)
nonisolated enum DataAccess {

    static func refreshMediaFileIfNeeded(_ mediaFile: MediaFile, maxAge: TimeInterval = 0, appDatabase: AppDatabase) async {
        let timeIntervalSinceLastFetchDate = Date.now.timeIntervalSince(mediaFile.fetchDate)

        guard timeIntervalSinceLastFetchDate > maxAge else { return }

        do {
            let isMediaFileUpToDate = try await Self.isMediaFileUpToDate(mediaFile)

            if isMediaFileUpToDate {
                // consider the media file to have been fetched now since the revid is idential
                try appDatabase.updateLastFetchedToNow(mediaFile.id)
            } else {
                // NOTE: changes from refresh will propagate into the DB observation further above.
                await DataAccess.refreshMediaFileFromNetwork(id: mediaFile.id, appDatabase: appDatabase)
            }
        } catch {
            logger.error("failed to refreshMediaFileIfNeeded \(mediaFile.name), \(error)")
            return
        }
    }

    static func refreshMediaFileFromNetwork(id: MediaFile.ID, appDatabase: AppDatabase) async {
        do {
            guard
                let result = try await Networking.shared.api
                    .fetchFullFileMetadata(.pageids([id])).first
            else {
                return
            }

            let refreshedMediaFile = MediaFile(apiFileMetadata: result)
            // NOTE: upserting here, will propagate the change in the DB observation further down.
            try appDatabase.upsert([refreshedMediaFile])
        } catch {
            logger.error("Failed to refresh media file \(error)")
        }
    }

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

    /// resolves categories based on commons categories and depict items (eg. from a MediaFile), always caches API results
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
            let cachedByWikidataID = (try? appDatabase.fetchCategoryInfos(wikidataIDs: wikidataIDs, resolveRedirections: true))?.compactMap(\.base) ?? []
            let cachedByCommonsCategory = (try? appDatabase.fetchCategoryInfos(commonsCategories: commonsCategories))?.compactMap(\.base) ?? []
            cachedCategories = (cachedByWikidataID + cachedByCommonsCategory).uniqued(on: { $0.wikidataId ?? $0.commonsCategory })
        }

        let cachedIDs = cachedCategories.compactMap(\.wikidataId)
        let cachedCommonsCategories = cachedCategories.compactMap(\.commonsCategory)
        let missingIDs = Set(wikidataIDs).subtracting(cachedIDs)
        let missingCommonsCategories = Set(commonsCategories).subtracting(cachedCommonsCategories)
        var fetchResult: CategoryFetchResult?


        if !missingIDs.isEmpty || !missingCommonsCategories.isEmpty {
            fetchResult = try await fetchWikidataBackedCategoriesFromAPI(
                wikidataIDs: Array(missingIDs),
                commonsCategories: commonsCategories,
                shouldCache: true,
                appDatabase: appDatabase
            )
        }

        let fetchedCategories = fetchResult?.fetchedCategories ?? []

        let fetchedAndCachedCombined = cachedCategories + fetchedCategories
        let groupedByWikidataID = fetchedAndCachedCombined.grouped(by: \.wikidataId)
        let groupedByCommonsCategory = fetchedAndCachedCombined.grouped(by: \.commonsCategory)

        let sortedByWikidataID: [Category] = wikidataIDs.compactMap { id in
            let redirectID = fetchResult?.redirectedIDs[id]
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

        // NOTE: Some categories are already cached when calling fetchWikidataBackedCategoriesFromAPI
        // but pure commons categories are, not. So to be complete, we upsert all final results here.
        let upserted = try appDatabase.upsertAndFetchOrdered(resultCategories)

        return .init(
            fetchedCategories: upserted,
            redirectedIDs: fetchResult?.redirectedIDs ?? [:]
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
            let insertedCategories = try appDatabase.upsertAndFetchOrdered(
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

    /// resolves Tags based on commons categories and depict items in MediaFile
    /// will return redirected (merged) items instead of original ones!
    @discardableResult
    static func resolveTags(of mediaFiles: [MediaFile], appDatabase: AppDatabase, forceNetworkRefresh: Bool = false) async throws -> [TagItem] {

        let depictWikdataIDs: [String] =
            mediaFiles
            .flatMap(\.statements)
            .filter(\.isDepicts)
            .compactMap(\.mainItem?.id)

        let commonsCategories = mediaFiles.flatMap(\.categories)


        let result = try await fetchCombinedCategoriesFromDatabaseOrAPI(
            wikidataIDs: depictWikdataIDs,
            commonsCategories: commonsCategories,
            forceNetworkRefresh: forceNetworkRefresh,
            appDatabase: appDatabase
        )

        let depictIDsWithResolvedRedirects: [String] = depictWikdataIDs.map { depictID in
            result.redirectedIDs[depictID] ?? depictID
        }

        let categoriesSet = Set(commonsCategories)
        let depictIDSet = Set(depictIDsWithResolvedRedirects)

        return result.fetchedCategories.map {
            var picked: Set<TagType> = []
            if let wikidataID = $0.wikidataId, depictIDSet.contains(wikidataID) {
                picked.insert(.depict)
            }
            if let commonsCategory = $0.commonsCategory, categoriesSet.contains(commonsCategory) {
                picked.insert(.category)
            }
            return .init($0, pickedUsages: picked)
        }
    }


    static func searchCategories(for searchText: String, referenceCoordinate: CLLocationCoordinate2D?, appDatabase: AppDatabase) async throws -> [ScoredCategoryInfo] {
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"

        async let wikidataSearchTask = try await Networking.shared.api
            .searchWikidataItems(term: searchText, languageCode: languageCode)
        async let categorySearchTask = try await Networking.shared.api
            .searchCategories(for: searchText, limit: .count(50))

        let (searchItems, searchCategories) = try await (
            wikidataSearchTask.search,
            categorySearchTask.items.compactMap { String($0.title.split(separator: "Category:")[0]) }
        )


        // TODO: would be easier if fetchCombinedCategoriesFromDatabaseOrAPI already returned [CategoryInfo] instead of Category.
        // but not super trivial due to other dependencies of `CategoryFetchResult`
        let fetchResult =
            try await fetchCombinedCategoriesFromDatabaseOrAPI(
                wikidataIDs: searchItems.map(\.id),
                commonsCategories: searchCategories,
                forceNetworkRefresh: false,
                appDatabase: appDatabase
            )

        let fetchedCategories = fetchResult.fetchedCategories

        assert(fetchedCategories.allSatisfy { $0.id != nil }, "We expect all categories returned from the above method to be cached!")

        // we use the original API return order, to compute the `apiRelevanceScore` to be used in the sortScore function.

        let fetchedIDs = fetchedCategories.compactMap { $0.id }
        let categoryInfos = try appDatabase.fetchCategoryInfos(ids: fetchedIDs)

        var originalItemScores: [String?: Double] = .init()
        var originalCategoryScores: [String?: Double] = .init()
        for (i, category) in searchCategories.enumerated() {
            originalCategoryScores[category] = 1.0 - (Double(i) / Double(searchCategories.count))
        }
        for (i, id) in searchItems.map(\.id).enumerated() {
            let relevance = 1.0 - (Double(i) / Double(searchItems.count))

            // A searched item may have been merged, in which case the returned


            originalItemScores[id] = max(originalItemScores[id] ?? 0, relevance)

            // resolved Categories have a redirected target id. So for good measure
            // also take potential old/redirect ids into account from the original API result.
            if let redirectedID = fetchResult.redirectedIDs[id] {
                originalItemScores[redirectedID] = max(originalItemScores[redirectedID] ?? 0, relevance)
            }
        }

        let result: [ScoredCategoryInfo] = categoryInfos.map { categoryInfo in
            let categoryScore = originalCategoryScores[categoryInfo.base.commonsCategory] ?? 0
            let itemScore = originalItemScores[categoryInfo.base.wikidataId] ?? 0
            let apiRelevanceScore = max(categoryScore, itemScore)
            let score = categoryInfo.sortScore(searchText: searchText, apiRelevanceScore: apiRelevanceScore, referenceCoordinate: referenceCoordinate)
            return (score, categoryInfo)
        }

        return result
    }

    private static func isMediaFileUpToDate(_ mediaFile: MediaFile) async throws -> Bool {
        guard let revid = mediaFile.revid else { return false }
        let mostRecentRevid = try await Networking.shared.api.fetchMostRecentRevid(pageID: mediaFile.pageID)
        return revid == mostRecentRevid
    }
}

nonisolated extension CategoryInfo {
    fileprivate func sortScore(searchText: String, apiRelevanceScore: Double = 0.0, referenceCoordinate: CLLocationCoordinate2D?) -> Double {
        var bookmarkScore = 0.0
        var lastViewedScore = 0.0
        var distScore = 0.0
        var textMatchScore = 0.0


        if isBookmarked {
            bookmarkScore = 1
        }

        if let lastViewed {
            let timeInterval = Date.now.timeIntervalSince(lastViewed)
            // the shorter the time interval the higher the score.
            // we are interested in the last 48h.
            // normalized to 0.01...1,
            // (not to 0...1, because we if the item was viewed already, its still more relevant than non-viewed categories)
            lastViewedScore = 1.0 - (timeInterval / (48 * 60 * 60))
            lastViewedScore = min(1, lastViewedScore)
            lastViewedScore = max(0.01, lastViewedScore)
        }

        if let referenceCoordinate, let c = self.base.coordinate {
            let categoryLocation = CLLocation(latitude: c.latitude, longitude: c.longitude)
            let referenceLocation = CLLocation(latitude: referenceCoordinate.latitude, longitude: referenceCoordinate.longitude)
            let dist = categoryLocation.distance(from: referenceLocation)

            // the shorter the distance, the higher the score, don't score-boost too long distances (maxDist)
            // maxDist is arbitrarily chosen, may need to be adjusted.
            let maxDist: Double = 10_000

            distScore = 1 - (dist / maxDist)
            distScore = min(1, distScore)
            distScore = max(0, distScore)

        }

        let commonsCategory = base.commonsCategory ?? ""
        let label = base.label ?? ""
        let desc = base.description ?? ""
        let commonsCategoryScore = calcTextMatchScore(reference: searchText, candidate: commonsCategory)
        let labelScore = calcTextMatchScore(reference: searchText, candidate: label)
        let descScore = calcTextMatchScore(reference: searchText, candidate: desc)

        textMatchScore = max(commonsCategoryScore, labelScore, descScore)

        let score = apiRelevanceScore + bookmarkScore + lastViewedScore + distScore + textMatchScore

        logger.debug(
            """
            \n
            sort score of \(base.commonsCategory ?? base.label ?? base.description ?? "")
            bookmarkScore: **\(score)**)
            lastViewedScore: **\(score)**)
            distScore: **\(score)**)
            textMatchScore: **\(score)**)

            total score: **\(score)**)
            \n
            """
        )

        return score
    }

    private func calcTextMatchScore(reference: String, candidate: String) -> Double {
        guard candidate.count > 0 else { return 0 }
        let reference = reference.localizedLowercase
        let candidate = candidate.localizedLowercase
        let prefixCount = Double(candidate.commonPrefix(with: reference).count)
        let refContainsCandidate = candidate.localizedStandardContains(reference)

        let normalizedRef = reference.replacing(.word.inverted, with: " ")
        let normalizedCandidate = candidate.replacing(.word.inverted, with: " ")

        let refWordsSet = Set(
            normalizedRef
                .split(separator: .word.inverted, omittingEmptySubsequences: true)
                .map(\.localizedLowercase)
        )
        let candidateWordsSet = Set(
            normalizedCandidate
                .split(separator: .whitespace, omittingEmptySubsequences: true)
                .map(\.localizedLowercase)
        )

        let totalUniqueWords = refWordsSet.union(candidateWordsSet).count
        let sameWordCount = refWordsSet.intersection(candidateWordsSet).count

        let matchingWordsScore = Double(sameWordCount) / Double(totalUniqueWords)
        let prefixScore = prefixCount / Double(candidate.count)
        let containsScore = refContainsCandidate ? 0.5 : 0

        let totalScore = (matchingWordsScore + prefixScore + containsScore) / 3
        return totalScore
    }
}
