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
    private let order: SearchOrder
    private let deepCategorySearch: Bool
    private let searchString: String

    @ObservationIgnored
    private var categoryContinueString: String?
    @ObservationIgnored
    private var depictSearchOffset: Int?
    private var incategorySearchOffset: Int?

    init(appDatabase: AppDatabase, categoryName: String?, depictItemID: String?, order: SearchOrder, deepCategorySearch: Bool, searchString: String) async throws {
        self.categoryName = categoryName
        self.depictItemID = depictItemID
        self.order = order
        self.deepCategorySearch = deepCategorySearch
        self.searchString = searchString
        try await super.init(appDatabase: appDatabase, initialIDs: [])
    }

    private func fetchRawContinueCategoryItems() async throws -> (pageIDs: [String], Int?)? {
        if let categoryName {
            let searchString = searchString.isEmpty ? "" : "\"\(searchString)\""
            let result = try await Networking.shared.api.searchFiles(
                for: "\(deepCategorySearch ? "deepcategory" : "incategory"):\"\(categoryName)\" \(searchString)",
                sort: order.apiType,
                limit: .max,
                offset: incategorySearchOffset
            )
            let pageIDs = result.items.compactMap(\.pageid).map(String.init)
            return (pageIDs: pageIDs, result.offset)
        } else {
            return nil
        }
    }

    private func fetchRawContinueDepictItems() async throws -> (pageIDs: [String], Int?)? {
        if let depictItemID {
            let result = try await Networking.shared.api.searchFiles(
                for: "haswbstatement:P180=\(depictItemID)",
                sort: order.apiType,
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

        incategorySearchOffset = categoryResult?.1
        depictSearchOffset = depictResult?.1

        let zippedIDs = zippedFlatMap(categoryIDs, depictIDs).uniqued(on: \.self)
        let canContinue = categoryContinueString != nil || depictSearchOffset != nil
        return (.pageids(zippedIDs), canContinue)
    }
}
