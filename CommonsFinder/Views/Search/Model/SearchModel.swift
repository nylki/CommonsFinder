//
//  SearchModel.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 29.10.24.
//

import Algorithms
import AppIntents
import AsyncAlgorithms
import CommonsAPI
import SwiftUI
import os.log

@MainActor
@Observable final class SearchModel {
    /// Only to be used when SwiftUI Environment is not available (AppIntents etc.)

    private var searchText: String = ""
    var bindableSearchText: String {
        get { searchText }
        set {
            guard newValue != searchText else { return }
            mediaResults = nil
            categoryResults = nil
            searchTask?.cancel()

            searchText = newValue

            if !searchText.isEmpty {
                fetchSearchSuggestions(for: searchText)
            }
        }
    }

    /// When this values changes the observing view may attempt to to focus the search-field
    private(set) var searchFieldFocusTrigger: Int = 0
    private(set) var suggestions: [String] = []
    private(set) var order: SearchOrder = .relevance

    var scope: SearchScope = .all

    var isSearching: Bool {
        !searchText.isEmpty && searchTask != nil || ((mediaItems.isEmpty || categoryItems.isEmpty) && (mediaPaginationStatus == .isPaginating || categoryPaginationStatus == .isPaginating))
    }

    var mediaItems: [MediaFileInfo] { mediaResults?.mediaFileInfos ?? [] }
    var categoryItems: [CategoryInfo] { categoryResults?.categoryInfos ?? [] }


    var mediaPaginationStatus: PaginationStatus {
        mediaResults?.status ?? .unknown
    }
    var categoryPaginationStatus: PaginationStatus {
        categoryResults?.status ?? .unknown
    }

    var mediaResults: PaginatableSearchMediaFiles?
    var categoryResults: PaginatableCategorySearch?

    private var searchTask: Task<Void, Never>?
    private var suggestTask: Task<Void, Never>?

    @ObservationIgnored
    private let appDatabase: AppDatabase

    init(appDatabase: AppDatabase, searchText: String = "", mediaResults: PaginatableSearchMediaFiles? = nil, categoryResults: PaginatableCategorySearch? = nil) {
        self.appDatabase = appDatabase
        self.searchText = searchText
        self.mediaResults = mediaResults
        self.categoryResults = categoryResults
    }

    func mediaPagination() {
        mediaResults?.paginate()
    }
    func categoryPagination() {
        categoryResults?.paginate()
    }

    func focusSearchField() {
        searchFieldFocusTrigger += 1
    }

    func setOrder(_ order: SearchOrder) {
        self.order = order
        mediaResults = nil
        categoryResults = nil
        search()
    }

    /// sets `text`as the searchText and  immediately submits the search
    func search(text: String) {
        guard text != searchText else { return }
        searchText = text
        if !searchText.isEmpty {
            search()
        }
    }

    /// searches for the current searchText
    func search() {
        guard !searchText.isEmpty else { return }
        guard searchTask == nil || searchTask?.isCancelled == true else { return }
        let resultsAlreadyFetched = (mediaResults?.searchString == searchText && categoryResults?.searchString == searchText)
        guard !resultsAlreadyFetched else { return }

        mediaResults = nil
        categoryResults = nil
        suggestTask?.cancel()
        searchTask?.cancel()

        let searchIntent = InAppSearchIntent()
        searchIntent.criteria = .init(term: searchText)
        searchIntent.donate()

        searchTask = Task {
            let trimmedText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            do {
                async let mediaSearch = PaginatableSearchMediaFiles(
                    appDatabase: appDatabase,
                    searchString: trimmedText,
                    order: order
                )

                async let categorySearch = PaginatableCategorySearch(
                    appDatabase: appDatabase,
                    searchString: trimmedText,
                    sort: order
                )

                let (mediaResults, categoryResults) = try await (mediaSearch, categorySearch)
                self.mediaResults = mediaResults
                self.categoryResults = categoryResults

            } catch {
                logger.error("Failed to search for \(trimmedText). \(error)")
            }
            searchTask = nil
        }

    }

    private func fetchSearchSuggestions(for text: String) {
        guard searchTask == nil else { return }
        suggestTask?.cancel()
        suggestTask = Task {
            do {
                try? await Task.sleep(for: .milliseconds(250))

                guard !Task.isCancelled else { return }
                logger.debug("Searching suggestions for \"\(text)\"")
                let terms = try await API.shared.searchSuggestedSearchTerms(for: text, limit: .max, namespaces: [.category, .main])
                guard !Task.isCancelled else { return }
                suggestions =
                    terms.map { term in
                        term.components(separatedBy: "Category:")[safeIndex: 1] ?? term.components(separatedBy: "File:")[safeIndex: 1] ?? term
                    }
                    .uniqued(on: { $0 })

            } catch is CancellationError {
                logger.debug("Suggest task cancelled.")
            } catch {
                logger.debug("search suggestions cancelled or failed \(error)")

            }

        }
    }
}

extension SearchModel {
    enum SearchScope: String, CaseIterable {
        case all
        case categories
        case images
    }
}
