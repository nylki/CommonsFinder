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

    @State private var isOptionsBarSticky = false
    @State private var scrollState: ScrollState = .init()

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
        .overlay(alignment: .top) {
            if !searchModel.isSearching, !searchModel.bindableSearchText.isEmpty {
                let stickyOptionsBarVisible =
                    isOptionsBarSticky && searchModel.mediaResults != nil && searchModel.mediaResults?.isEmpty != nil && scrollState.lastDirection == .up && scrollState.phase == .idle

                if stickyOptionsBarVisible {
                    optionsBar
                }
            }
        }
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
        .onSubmit(of: .search, searchModel.search)
        .navigationTitle("Search")
        .toolbarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var searchResultView: some View {
        let dragGesture = DragGesture(minimumDistance: 25, coordinateSpace: .local)
            .onChanged { v in
                let newDirection: ScrollState.Direction =
                    if v.predictedEndLocation.y > v.startLocation.y {
                        .up
                    } else if v.predictedEndLocation.y < v.startLocation.y {
                        .down
                    } else {
                        .none
                    }

                guard newDirection != scrollState.lastDirection else { return }
                scrollState.lastDirection = newDirection
            }

        switch searchModel.scope {
        case .all:
            ScrollView(.vertical) {

                HorizontalCategoryList
                    .padding(.bottom)

                if !searchModel.isSearching, !searchModel.bindableSearchText.isEmpty, searchModel.mediaResults != nil {
                    optionsBar
                        .opacity(isOptionsBarSticky ? 0 : 1)
                        .allowsHitTesting(!isOptionsBarSticky)
                        .onScrollVisibilityChange(threshold: 0.1) { visible in
                            isOptionsBarSticky = !visible
                        }
                }

                PaginatableMediaList(
                    items: searchModel.mediaItems,
                    status: searchModel.mediaPaginationStatus,
                    toolOverlayPadding: false,
                    paginationRequest: searchModel.mediaPagination
                )
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(dragGesture)
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
                    toolOverlayPadding: false,
                    paginationRequest: searchModel.mediaPagination
                )
                .id("images")
            }
        }
    }

    @ViewBuilder
    private var optionsBar: some View {
        HStack {
            SearchOrderButton(searchOrder: searchModel.orderBinding)
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var HorizontalCategoryList: some View {
        let items = searchModel.categoryResults?.categoryInfos ?? []
        let hasCategoriesLoaded = !items.isEmpty
        let isLoadingCategories = searchModel.categoryPaginationStatus == .isPaginating
        ZStack {
            if hasCategoriesLoaded {
                ScrollView(.horizontal) {
                    let fallbackToSingleRowGrid = items.count <= 2
                    LazyHGrid(rows: fallbackToSingleRowGrid ? [.init()] : [.init(), .init()]) {

                        ForEach(items) { categoryInfo in
                            CategoryTeaser(categoryInfo: categoryInfo)
                                .frame(width: 260, height: 200)
                                .onScrollVisibilityChange { visible in
                                    guard visible else { return }
                                    let threshold = min(items.count - 1, max(0, items.count - 5))
                                    guard threshold > 0 else { return }
                                    let thresholdItem = items[threshold]

                                    if categoryInfo == thresholdItem {
                                        searchModel.categoryResults?.paginate()
                                    }
                                }
                        }

                        if searchModel.categoryResults?.status == .isPaginating {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .frame(width: 260, height: 300)
                        }
                    }
                    .scrollTargetLayout()
                    .scenePadding(.horizontal)
                    .animation(.default, value: items)

                }
                .scrollTargetBehavior(.viewAligned)
            } else if isLoadingCategories {
                let height: Double = (searchModel.categoryResults?.rawCount ?? 0) <= 2 ? 200 : 400
                ProgressView()
                    .frame(height: height)
                    .containerRelativeFrame(.horizontal)
            }
        }
        .padding(.top, 50)
        .animation(.default, value: hasCategoriesLoaded)
        .animation(.default, value: searchModel.categoryPaginationStatus)
        .animation(.default, value: searchModel.categoryResults?.rawCount)
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
