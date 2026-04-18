//
//  SearchView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 03.10.24.
//

import FrameUp
import NukeUI
import SwiftUI

struct SearchView: View {
    @Environment(SearchModel.self) private var searchModel
    @Environment(Navigation.self) private var navigation

    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        @Bindable var searchModel = searchModel

        VStack {
            if searchModel.isSearching {
                ProgressView()
            } else {
                searchResultView
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .onChange(of: searchModel.searchFieldFocusTrigger) {
            isSearchFieldFocused = true
        }
        .animation(.default, value: searchModel.isSearching)
        .animation(.default, value: searchModel.scope)
        .searchable(
            text: $searchModel.bindableSearchText,
            prompt: "Search on Wikimedia Commons"
        )
        //        .searchScopes($searchModel.scope) {
        //            ForEach(SearchModel.SearchScope.allCases, id: \.self) {
        //                Text($0.rawValue)
        //            }
        //        }
        .searchFocused($isSearchFieldFocused)
        .searchSuggestions {
            ForEach(searchModel.suggestions, id: \.self) {
                Text($0).searchCompletion($0)
            }
        }
        .searchPresentationToolbarBehavior(.avoidHidingContent)
        .onSubmit(of: .search, searchModel.search)
        .navigationTitle("Search")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            SearchOrderButton(searchOrder: searchModel.orderBinding, possibleCases: [.relevance, .newest, .oldest])
        }
    }

    @ViewBuilder
    private var searchResultView: some View {
        switch searchModel.scope {
        case .all:
            ScrollView(.vertical) {
                Color.clear.frame(minWidth: 0, maxWidth: .infinity)

                if let model = searchModel.categoryResults {
                    HorizontalCategoryList(model: model)
                }

                if !searchModel.isSearching, !searchModel.bindableSearchText.isEmpty {
                    if searchModel.mediaResults?.isEmpty == false {
                        PaginatableMediaList(
                            items: searchModel.mediaItems,
                            status: searchModel.mediaPaginationStatus,
                            paginationRequest: searchModel.mediaPagination
                        )
                    } else if searchModel.mediaResults?.isEmpty == true {
                        ContentUnavailableView.search(text: searchModel.bindableSearchText)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .id("all")
        case .categories:
            ScrollView(.vertical) {
                PaginatableCategoryList(
                    items: searchModel.categoryItems,
                    status: searchModel.categoryPaginationStatus,
                    paginationRequest: searchModel.categoryPagination
                )
                .id("categories")
            }

        case .images:
            ScrollView(.vertical) {
                PaginatableMediaList(
                    items: searchModel.mediaItems,
                    status: searchModel.mediaPaginationStatus,
                    paginationRequest: searchModel.mediaPagination
                )
                .id("images")
            }
        }
    }
}

#Preview(
    "Prefilled full",
    traits: .previewEnvironment(
        prefilledSearchMedia: [
            .makeRandomUploaded(id: "1", .horizontalImage),
            .makeRandomUploaded(id: "1", .verticalImage),
            .makeRandomUploaded(id: "1", .squareImage),
        ],
        prefilledSearchCategories: [
            .randomItem(id: "1"),
            .randomItem(id: "2"),
            .randomItem(id: "3"),
            .randomItem(id: "4"),
            .randomItem(id: "5"),
            .randomItem(id: "6"),
            .randomItem(id: "7"),
            .randomItem(id: "8"),
            .randomItem(id: "9"),
        ]
    )
) {
    NavigationView {
        SearchView()
    }
}

#Preview(
    "Prefilled few",
    traits: .previewEnvironment(
        prefilledSearchMedia: [
            .makeRandomUploaded(id: "1", .horizontalImage)
        ],
        prefilledSearchCategories: [
            .randomItem(id: "1")
        ]
    )
) {
    NavigationView {
        SearchView()
    }
}

#Preview("Actual Search", traits: .previewEnvironment) {
    @Previewable @Environment(SearchModel.self) var searchModel
    NavigationView {
        SearchView()
            .task {
                searchModel.search(text: "uni gardening adlershof")
            }
    }
}
