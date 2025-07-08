//
//  InAppSearchIntent.swift.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 03.10.24.
//

import AppIntents
import Foundation
import UniformTypeIdentifiers
import os.log

@AssistantIntent(schema: .system.search)
struct InAppSearchIntent: AppIntent, ShowInAppSearchResultsIntent {
    static let searchScopes: [StringSearchScope] = [.general]
    @Parameter
    var criteria: StringSearchCriteria

    @Dependency
    private var navigationModel: Navigation

    @Dependency
    private var searchModel: SearchModel

    @MainActor
    func perform() async throws -> some IntentResult {
        let searchString = criteria.term

        logger.info("AppIntent: Searching for \(searchString)")
        searchModel.setSearchText(searchString, fetchSuggestions: false, shouldDebounce: false)
        navigationModel.selectedTab = .search
        Task<Void, Never> {
            try? await Task.sleep(for: .milliseconds(250))
            searchModel.focusSearchField()
        }

        return .result()
    }
}
