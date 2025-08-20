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

enum APIUtils {
    static func searchCategories(for searchText: String) async throws -> [Category] {
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"

        async let wikidataSearchTask = try await API.shared
            .searchWikidataItems(term: searchText, languageCode: languageCode)
        async let categorySearchTask = try await API.shared
            .searchCategories(term: searchText, limit: .count(50))

        let (searchItems, searchCategories) = try await (wikidataSearchTask, categorySearchTask)

        async let resolvedWikiItemsTask = API.shared
            .fetchGenericWikidataItems(itemIDs: searchItems.map(\.id), languageCode: languageCode)

        /// categories often have associated wikidataItems( & vice-versa, see above), resolve wiki items for the found categories:
        async let resolvedCategoryItemsTask = API.shared
            .findWikidataItemsForCategories(searchCategories, languageCode: languageCode)

        let (resolvedWikiItems, resolvedCategoryItems) = try await (resolvedWikiItemsTask, resolvedCategoryItemsTask)

        // We need to sort our resolved items along the original search order
        // because they arrive sorted by relevance, and we want the most relevant on top/first.
        let sortedWikiItems = searchItems.compactMap { searchItem in
            resolvedWikiItems.first(where: { $0.id == searchItem.id })
        }
        let sortedCategoryItems = searchCategories.compactMap { category in
            resolvedCategoryItems.first(where: { $0.commonsCategory == category })
        }

        // Prefer label and description from action API (because of language fallback):
        let labelAndDescription = searchItems.grouped(by: \.id)
        let combinedWikidataItems = (sortedWikiItems + sortedCategoryItems).uniqued(on: \.id)

        let wikiItemCategories: [Category] = combinedWikidataItems.map { apiItem in
            var item = Category(apiItem: apiItem)
            item.label = labelAndDescription[apiItem.id]?.first?.label ?? item.label
            item.description = labelAndDescription[apiItem.id]?.first?.description ?? item.description
            return item
        }

        // Only keep categories that do not already have a wikidata item
        let pureCommonsCategories: [Category] = searchCategories.compactMap { categoryName in
            let isAlreadyInWikiItems = wikiItemCategories.contains(where: { $0.commonsCategory == categoryName })
            if isAlreadyInWikiItems { return nil }
            return Category(commonsCategory: categoryName)
        }

        return wikiItemCategories + pureCommonsCategories

    }
}
