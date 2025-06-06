//
//  PaginatableSearchMediaFiles.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 02.05.25.
//

import CommonsAPI
import Foundation
import SwiftUI

@Observable @MainActor final class PaginatableSearchMediaFiles: PaginatableMediaFiles {
    var searchString: String = ""
    var offset: Int?
    let sort: SearchOrder

    init(appDatabase: AppDatabase, searchString: String, order: SearchOrder = .relevance) async throws {
        self.sort = order
        self.searchString = searchString
        try await super.init(appDatabase: appDatabase)
    }

    override internal func
        fetchRawContinuePaginationItems() async throws -> (items: [String], reachedEnd: Bool)
    {
        let result = try await CommonsAPI.API.shared.searchFiles(
            for: searchString,
            sort: sort.apiType,
            limit: .max,
            offset: offset
        )

        offset = result.offset
        return (result.items.map(\.title), offset != nil)
    }
}

extension SearchOrder {
    fileprivate var apiType: CommonsAPI.API.SearchSort {
        switch self {
        case .relevance: .relevance
        case .newest: .createTimestampDesc
        }
    }
}
