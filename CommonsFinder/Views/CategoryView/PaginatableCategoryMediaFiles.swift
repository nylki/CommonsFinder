//
//  PaginatableCategoryMediaFiles.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 17.03.25.
//

import Algorithms
import CommonsAPI
import Foundation
import OrderedCollections
import SwiftUI
import os.log

@Observable final class PaginatableCategoryMediaFiles: PaginatableMediaFiles {
    private let categoryName: String?
    private let depictItemID: String?

    @ObservationIgnored
    private var categoryContinueString: String?
    @ObservationIgnored
    private var depictSearchOffset: Int?

    init(appDatabase: AppDatabase, categoryName: String?, depictItemID: String?) async throws {
        self.categoryName = categoryName
        self.depictItemID = depictItemID
        try await super.init(appDatabase: appDatabase, initialIDs: [])
    }

    private func fetchRawContinueCategoryItems() async throws -> (pageIDs: [String], String?)? {
        if let categoryName {
            let result = try await CommonsAPI.API.shared.listCategoryImagesRaw(
                of: categoryName,
                continueString: categoryContinueString
            )
            let pageIDs = result.files.compactMap(\.pageid).map(String.init)
            return (pageIDs: pageIDs, result.continueString)
        } else {
            return nil
        }
    }

    private func fetchRawContinueDepictItems() async throws -> (pageIDs: [String], Int?)? {
        if let depictItemID {
            let result = try await CommonsAPI.API.shared.searchFiles(
                for: "haswbstatement:P180=\(depictItemID)",
                sort: .relevance,
                limit: .max,
                offset: depictSearchOffset
            )
            let pageIDs = result.items.compactMap(\.pageid).map(String.init)
            return (pageIDs: pageIDs, result.offset)
        } else {
            return nil
        }
    }

    override func fetchRawContinuePaginationItems() async throws -> (fileIdentifiers: FileIdentifierList, canContinue: Bool) {
        async let categoryPagination = fetchRawContinueCategoryItems()
        async let depictPagination = fetchRawContinueDepictItems()

        let (categoryResult, depictResult) = try await (categoryPagination, depictPagination)

        let categoryIDs = categoryResult?.pageIDs ?? []
        let depictIDs = depictResult?.pageIDs ?? []

        categoryContinueString = categoryResult?.1
        depictSearchOffset = depictResult?.1

        let zippedIDs = zippedFlatMap(categoryIDs, depictIDs).uniqued(on: \.self)
        let canContinue = categoryContinueString != nil || depictSearchOffset != nil
        return (.pageids(zippedIDs), canContinue)
    }
}
