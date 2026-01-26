//
//  APIUtils.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 22.07.25.
//

import Algorithms
import CommonsAPI
import Foundation
import os.log

// TODO: create paginatable Model similar to paginatable files (or identical?)
//always paginate both wikidata, and category search when pagination is required and unique/ results // as necessary. eg.


nonisolated enum APIUtils {
    static func searchCategories(for searchText: String) async throws -> [Category] {
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"

        async let wikidataSearchTask = try await Networking.shared.api
            .searchWikidataItems(term: searchText, languageCode: languageCode)
        async let categorySearchTask = try await Networking.shared.api
            .searchCategories(for: searchText, limit: .count(50))

        let (searchItems, searchCategories) = try await (
            wikidataSearchTask.search,
            categorySearchTask.items.compactMap { String($0.title.split(separator: "Category:")[0]) }
        )

        return try await fetchCombinedCategories(wikidataItems: searchItems, commonsCategories: searchCategories)

    }

    /// returns an array of unique Categories by resolving both argument arrays deduplicating their results
    static func fetchCombinedCategories(wikidataItems: [WikidataSearchItem], commonsCategories: [String]) async throws -> [Category] {
        let languageCode = Locale.current.wikiLanguageCodeIdentifier
        async let resolvedWikiItemsTask = Networking.shared.api
            .fetchGenericWikidataItems(itemIDs: wikidataItems.map(\.id), languageCode: languageCode)

        /// categories often have associated wikidataItems( & vice-versa, see above), resolve wiki items for the found categories:
        async let resolvedCategoryItemsTask = Networking.shared.api
            .findWikidataItemsForCategories(commonsCategories, languageCode: languageCode)

        let (resolvedWikiItems, resolvedCategoryItems) = try await (resolvedWikiItemsTask, resolvedCategoryItemsTask)

        // We need to sort our resolved items along the original search order
        // because they arrive sorted by relevance, and we want the most relevant on top/first.
        let sortedWikiItems = wikidataItems.compactMap { item in
            resolvedWikiItems.first(where: { $0.id == item.id })
        }
        let sortedCategoryItems = commonsCategories.compactMap { category in
            resolvedCategoryItems.first(where: { $0.commonsCategory == category })
        }

        // Prefer label and description from action API (because of language fallback):
        let labelAndDescription = wikidataItems.grouped(by: \.id)
        let combinedWikidataItems = (sortedWikiItems + sortedCategoryItems).uniqued(on: \.id)

        let wikiItemCategories: [Category] = combinedWikidataItems.map { apiItem in
            var item = Category(apiItem: apiItem)
            item.label = labelAndDescription[apiItem.id]?.first?.label ?? item.label
            item.description = labelAndDescription[apiItem.id]?.first?.description ?? item.description
            return item
        }

        // Only keep categories that do not already have a wikidata item
        let pureCommonsCategories: [Category] = commonsCategories.compactMap { categoryName in
            let isAlreadyInWikiItems = wikiItemCategories.contains(where: { $0.commonsCategory == categoryName })
            if isAlreadyInWikiItems { return nil }
            return Category(commonsCategory: categoryName)
        }

        return wikiItemCategories + pureCommonsCategories
    }
}

extension SearchOrder {
    var apiType: CommonsAPI.API.SearchSort {
        switch self {
        case .relevance: .relevance
        case .newest: .createTimestampDesc
        case .oldest: .createTimestampAsc
        }
    }
}
