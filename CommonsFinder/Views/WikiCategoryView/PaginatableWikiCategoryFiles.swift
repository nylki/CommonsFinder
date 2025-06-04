//
//  File.swift
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

@Observable final class PaginatableWikiCategoryFiles: PaginatableMediaFiles {
    private let categoryName: String?
    private let depictItemID: String?

    @ObservationIgnored
    private var categoryContinueString: String?
    @ObservationIgnored
    private var depictSearchOffset: Int?

    init(appDatabase: AppDatabase, categoryName: String?, depictItemID: String?) async throws {
        self.categoryName = categoryName
        self.depictItemID = depictItemID
        try await super.init(appDatabase: appDatabase)
    }

    private func fetchRawContinueCategoryItems() async throws -> ([String], String?)? {
        if let categoryName {
            let result = try await CommonsAPI.API.shared.listCategoryImagesRaw(
                of: categoryName,
                continueString: categoryContinueString
            )
            return (result.files.map(\.title), result.continueString)
        } else {
            return nil
        }
    }

    private func fetchRawContinueDepictItems() async throws -> ([String], Int?)? {
        if let depictItemID {
            let result = try await CommonsAPI.API.shared.searchFiles(
                for: "haswbstatement:P180=\(depictItemID)",
                sort: .relevance,
                limit: .max,
                offset: depictSearchOffset
            )
            return (result.items.map(\.title), result.offset)
        } else {
            return nil
        }
    }

    override func fetchRawContinuePaginationItems() async throws -> (items: [String], canContinue: Bool) {
        async let categoryPagination = fetchRawContinueCategoryItems()
        async let depictPagination = fetchRawContinueDepictItems()

        let (categoryResult, depictResult) = try await (categoryPagination, depictPagination)

        logger.info("\(categoryResult?.0.count ?? 0) category files")
        logger.info("\(depictResult?.0.count ?? 0) wikidata depict files")

        var categoryTitles: [String] = categoryResult?.0 ?? []
        var depictTitles: [String] = depictResult?.0 ?? []

        var zippedTitles: [String] = []
        // Reverse arrays so we can .popLast() to get the first elemenets.
        categoryTitles.reverse()
        depictTitles.reverse()
        while !categoryTitles.isEmpty || !depictTitles.isEmpty {
            let poppedA = categoryTitles.popLast() ?? depictTitles.popLast()
            let poppedB = depictTitles.popLast() ?? categoryTitles.popLast()

            if let poppedA {
                zippedTitles.append(poppedA)
            }
            if let poppedB {
                zippedTitles.append(poppedB)
            }
        }

        categoryContinueString = categoryResult?.1
        depictSearchOffset = depictResult?.1
        let canContinue = categoryContinueString != nil || depictSearchOffset != nil
        return (zippedTitles.uniqued(on: \.self), canContinue)
    }
}
