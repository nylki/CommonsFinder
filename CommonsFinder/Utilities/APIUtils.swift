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

nonisolated enum APIUtils {
    static func searchCategories(for searchText: String, appDatabase: AppDatabase) async throws -> [Category] {
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"

        async let wikidataSearchTask = try await Networking.shared.api
            .searchWikidataItems(term: searchText, languageCode: languageCode)
        async let categorySearchTask = try await Networking.shared.api
            .searchCategories(for: searchText, limit: .count(50))

        let (searchItems, searchCategories) = try await (
            wikidataSearchTask.search,
            categorySearchTask.items.compactMap { String($0.title.split(separator: "Category:")[0]) }
        )

        return
            try await DataAccess.fetchCombinedCategoriesFromDatabaseOrAPI(
                wikidataIDs: searchItems.map(\.id),
                commonsCategories: searchCategories,
                forceNetworkRefresh: false,
                appDatabase: appDatabase
            )
            .fetchedCategories
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
