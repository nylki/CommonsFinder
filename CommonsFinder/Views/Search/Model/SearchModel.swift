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
            searchText = newValue
            result = nil
            if !searchText.isEmpty {
                fetchSearchSuggestions(for: searchText)
            } else {
                suggestions = []
            }

        }
    }

    /// When this values changes the observing view may attempt to to focus the search-field
    private(set) var searchFieldFocusTrigger: Int = 0
    private(set) var suggestions: [String] = []
    private(set) var order: SearchOrder = .relevance

    var isSearching: Bool {
        searchTask != nil || (items.isEmpty && paginationStatus == .isPaginating)
    }

    var items: [MediaFileInfo] { result?.mediaFileInfos ?? [] }
    var paginationStatus: PaginatableMediaFiles.Status {
        result?.status ?? .unknown
    }
    var result: PaginatableSearchMediaFiles?

    private var searchTask: Task<Void, Never>?
    private var suggestTask: Task<Void, Never>?

    @ObservationIgnored
    private var searchChannel: AsyncChannel<String> = .init()

    @ObservationIgnored
    private let appDatabase: AppDatabase

    init(appDatabase: AppDatabase, searchText: String = "", result: PaginatableSearchMediaFiles? = nil) {
        self.appDatabase = appDatabase
        self.searchText = searchText
        self.result = result
    }

    func paginate() {
        result?.paginate()
    }

    func focusSearchField() {
        searchFieldFocusTrigger += 1
    }

    func setOrder(_ order: SearchOrder) {
        self.order = order
        result = nil
        search()
    }

    /// sets `text`as the searchText and  immediately submits the search
    func search(text: String) {
        searchText = consume text
        guard !searchText.isEmpty else { return }
        search()
    }

    /// searches for the current searchText
    func search() {
        guard !searchText.isEmpty else { return }

        searchTask?.cancel()

        let searchIntent = InAppSearchIntent()
        searchIntent.criteria = .init(term: searchText)
        searchIntent.donate()

        result = nil
        searchTask = Task {
            let trimmedText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            do {

                let paginatableFiles = try await PaginatableSearchMediaFiles(
                    appDatabase: appDatabase,
                    searchString: trimmedText,
                    order: order
                )
                result = paginatableFiles
            } catch {
                logger.error("Failed to search for \(trimmedText). \(error)")
            }
            searchTask = nil
        }

    }

    private func fetchSearchSuggestions(for text: String) {
        suggestTask?.cancel()
        suggestTask = Task {
            do {
                try? await Task.sleep(for: .milliseconds(250))
                let terms = try await API.shared.searchSuggestedSearchTerms(for: text, namespaces: [.category, .main])
                guard !Task.isCancelled else { return }
                suggestions =
                    terms.map { term in
                        term.components(separatedBy: "Category:")[safeIndex: 1] ?? term.components(separatedBy: "File:")[safeIndex: 1] ?? term
                    }
                    .uniqued(on: { $0 })

            } catch is CancellationError {
                logger.debug("XXX Suggest task cancelled.")
            } catch {
                logger.error("XXX Failed to fetch search suggestions \(error)")
            }

        }
    }
}
