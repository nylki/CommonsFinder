//
//  PaginatableParentCategories.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 26.02.26.
//

import CommonsAPI
import Foundation
import GRDB
import os.log

enum CategoryMembersSort: String, Equatable, Hashable, CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .ascending:
            LocalizedStringResource(stringLiteral: "Ascending")
        case .descending:
            LocalizedStringResource(stringLiteral: "Descending")
        }
    }

    case ascending
    case descending

    var apiType: API.CategoryMembersSort {
        switch self {
        case .ascending: .ascending
        case .descending: .descending
        }
    }
}

@Observable class PaginatableParentCategories: PaginatableCategories {
    let categoryName: String
    let sort: CategoryMembersSort
    private var continueString: String?
    private var cmContinueString: String?

    init(appDatabase: AppDatabase, categoryName: String, sort: CategoryMembersSort) async throws {
        self.categoryName = categoryName
        self.sort = sort
        super.init(appDatabase: appDatabase, searchTargets: .commons)
        try await initialFetch()
    }

    init(previewAppDatabase: AppDatabase, categoryName: String, sort: CategoryMembersSort, prefilledCategories: [CategoryInfo]) {
        self.categoryName = categoryName
        self.sort = sort
        super.init(previewAppDatabase: previewAppDatabase, searchTargets: .commons, prefilledCategories: prefilledCategories)
    }

    override func rawCommonsCategoryPagination() async throws -> (categories: [String], canContinue: Bool) {
        let response = try await Networking.shared.api.fetchCategoryMembers(
            of: categoryName,
            sort: sort.apiType,
            continueString: continueString,
            cmContinueString: cmContinueString
        )

        continueString = response?.`continue`
        cmContinueString = response?.cmcontinue

        // NOTE: return only parent categories (instead of also subcategories) in this case
        let parentCategories = response?.parentCategories ?? []
        return (categories: parentCategories, canContinue: continueString != nil || cmContinueString != nil)
    }

    override func rawWikidataPagination() async throws -> (ids: [String], canContinue: Bool) {
        // Parent categories are only available via Commons API, not Wikidata
        return (ids: [], canContinue: false)
    }
}
