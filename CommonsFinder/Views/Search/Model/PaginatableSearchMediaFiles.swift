//
//  PaginatableSearchMediaFiles.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 02.05.25.
//

import CommonsAPI
import Foundation
import SwiftUI

@Observable final class PaginatableSearchMediaFiles: PaginatableMediaFiles {
    var searchString: String = ""
    var offset: Int?
    let sort: SearchOrder

    init(appDatabase: AppDatabase, searchString: String, order: SearchOrder = .relevance) async throws {
        self.sort = order
        self.searchString = searchString
        try await super.init(appDatabase: appDatabase, initialIDs: [])
    }

    init(previewAppDatabase: AppDatabase, searchString: String, prefilledMedia: [MediaFileInfo]) {
        self.sort = .relevance
        self.searchString = searchString
        super.init(previewAppDatabase: previewAppDatabase, initialTitles: [], mediaFileInfos: prefilledMedia)
    }

    override internal func
        fetchRawContinuePaginationItems() async throws -> (fileIdentifiers: FileIdentifierList, canContinue: Bool)
    {
        let result = try await Networking.shared.api.searchFiles(
            for: searchString,
            sort: sort.apiType,
            limit: .max,
            offset: offset
        )

        offset = result.offset
        let pageIDs = result.items.compactMap(\.pageid).map(String.init)
        return (fileIdentifiers: .pageids(pageIDs), canContinue: offset != nil)
    }
}
