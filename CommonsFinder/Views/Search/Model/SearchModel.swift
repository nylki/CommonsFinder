//
//  SearchModel.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 29.10.24.
//

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
        set { setSearchText(newValue) }
    }

    /// When this values changes the observing view may attempt to to focus the search-field
    private(set) var searchFieldFocusTrigger: Int = 0
    private(set) var suggestions: [String] = []
    private(set) var order: SearchOrder = .relevance

    var isSearching: Bool { searchTaskCount > 0 }
    var items: [MediaFileInfo] { cachedResults[searchText]?.mediaFileInfos ?? [] }
    var paginationStatus: PaginatableMediaFiles.Status {
        cachedResults[searchText]?.status ?? .unknown
    }

    @ObservationIgnored
    private var searchTaskCount: UInt = 0

    var cachedResults: [String: PaginatableSearchMediaFiles]

    @ObservationIgnored
    private var searchThrottleTask: Task<Void, Never>?
    @ObservationIgnored
    private var searchChannel: AsyncChannel<String> = .init()
    private let appDatabase: AppDatabase

    init(appDatabase: AppDatabase, searchText: String = "", cachedResults: [String: PaginatableSearchMediaFiles] = [:]) {
        self.appDatabase = appDatabase
        self.searchText = searchText
        self.cachedResults = cachedResults

        searchThrottleTask?.cancel()
        searchThrottleTask = Task {
            for await debouncedSearchText in searchChannel.debounce(for: .milliseconds(500)) {
                guard !Task.isCancelled else { break }
                logger.info("searching for: \(debouncedSearchText)...")
                scheduleSearch(for: debouncedSearchText)
            }
        }
    }

    func paginate() {
        cachedResults[searchText]?.paginate()
    }

    func focusSearchField() {
        searchFieldFocusTrigger += 1
    }

    func setOrder(_ order: SearchOrder) {
        self.order = order
        cachedResults.removeAll()
        if !searchText.isEmpty {
            scheduleSearch(for: searchText)
        }
    }

    /// Searches for `text` and returns [MediaFile] without setting the searchText
    func search(_ text: String) async throws {
        guard cachedResults[text] == nil else { return }
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let paginatableFiles = try await PaginatableSearchMediaFiles(appDatabase: appDatabase, searchString: trimmedText, order: self.order)
        cachedResults[text] = paginatableFiles
    }

    /// Sets the current searchText to `text` and will schedule a API search for the text.
    /// If `debounced` is set `true` the search will not be dispatched immediately but may be discarded in favor or more recent
    /// search text (... entered via the search bar).
    func setSearchText(_ text: String, fetchSuggestions: Bool = true, shouldDebounce: Bool = true) {
        searchText = text
        guard !searchText.isEmpty else { return }

        //        if fetchSuggestions {
        //            fetchSearchSuggestions(for: searchText)
        //        }

        if shouldDebounce {
            Task<Void, Never> {
                await searchChannel.send(searchText)
            }
        } else {
            scheduleSearch(for: searchText)
        }
    }


    private func fetchSearchSuggestions(for text: String) {
        Task {
            suggestions = try await API.shared.searchSuggestedSearchTerms(for: text, namespaces: [.file, .main])
        }
    }

    private func scheduleSearch(for text: String) {
        // NOTE: No need to cancel the search task, as the results will be cached per search text
        // TODO: maybe too complicated/future error-prone?? -> just one list of results instead?
        searchTaskCount += 1
        Task {
            defer { searchTaskCount -= 1 }
            do {
                guard !Task.isCancelled else { return }
                try await search(text)
                let searchIntent = InAppSearchIntent()
                searchIntent.criteria = .init(term: text)
                try await searchIntent.donate()
            } catch {
                logger.error("search failed \(error)")
            }
        }
    }
}
