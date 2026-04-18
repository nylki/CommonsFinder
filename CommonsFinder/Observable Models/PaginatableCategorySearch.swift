//
//  PaginatableCategories.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 25.08.25.
//

import Algorithms
import CommonsAPI
import Foundation
import GRDB
import os.log

@Observable class PaginatableCategorySearch: PaginatableCategories {
    let searchString: String
    let parentCategory: String?
    let sort: SearchOrder

    private var commonsOffset: Int?
    private var wikidataOffset: Int?

    @ObservationIgnored
    private var canContinueWikidataPagination = false
    @ObservationIgnored
    private var canContinueCommonsPagination = false


    init(appDatabase: AppDatabase, searchString: String, inParentCategory parentCategory: String? = nil, sort: SearchOrder, searchTargets: CategorySearchTargets = .all) async throws {
        self.searchString = searchString
        self.sort = sort
        self.parentCategory = parentCategory
        super.init(appDatabase: appDatabase, searchTargets: searchTargets)
        try await initialFetch()
    }

    init(previewAppDatabase: AppDatabase, searchString: String, inParentCategory parentCategory: String? = nil, prefilledCategories: [CategoryInfo], searchTargets: CategorySearchTargets = .all) {
        self.sort = .relevance
        self.searchString = searchString
        self.parentCategory = parentCategory
        super.init(appDatabase: previewAppDatabase, searchTargets: searchTargets)
        self.categoryInfos = prefilledCategories
    }

    override func rawWikidataPagination() async throws -> (ids: [String], canContinue: Bool) {
        let result = try await Networking.shared.api.searchWikidataItems(
            term: searchString,
            languageCode: Locale.current.wikiLanguageCodeIdentifier,
            offset: wikidataOffset
        )
        wikidataOffset = result.searchContinue

        return (ids: result.search.map(\.id), canContinue: wikidataOffset != nil)
    }

    override func rawCommonsCategoryPagination() async throws -> (categories: [String], canContinue: Bool) {
        let term =
            if let parentCategory {
                "incategory:\"\(parentCategory)\""
            } else {
                searchString
            }
        let result = try await Networking.shared.api.searchCategories(
            for: term,
            sort: sort.apiType,
            limit: .max,
            offset: commonsOffset
        )

        commonsOffset = result.offset

        let categoriesWithoutPrefix = result.items.map {
            String($0.title.split(separator: "Category:")[0])
        }

        return (categories: categoriesWithoutPrefix, canContinue: commonsOffset != nil)
    }
}
