//
//  SearchView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 03.10.24.
//

import NukeUI
import SwiftUI

struct SearchView: View {
    @Environment(SearchModel.self) private var searchModel
    @Environment(Navigation.self) private var navigation

    @FocusState private var isSearchFieldFocused: Bool

    @State private var isOptionBarVisible = true
    @State private var isScrolledDown = false


    var body: some View {
        @Bindable var searchModel = searchModel

        VStack {
            if searchModel.isSearching {
                ProgressView().frame(height: 500)
            } else if searchModel.bindableSearchText.isEmpty {
                searchResultView
            } else {
                searchResultView
            }

        }
        .onScrollPhaseChange { oldPhase, newPhase, context in
            let geometry = context.geometry
            withAnimation {
                isOptionBarVisible = (newPhase == .idle)
            }

            let totalScrollOffset = geometry.contentOffset.y + geometry.contentInsets.top
            isScrolledDown = totalScrollOffset > 1
        }
        .scrollDismissesKeyboard(.immediately)
        .overlay(alignment: .top) {
            if !searchModel.isSearching, isOptionBarVisible { optionBar }
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
        switch searchModel.scope {
        case .all:
            ScrollView(.vertical) {
                HorizontalCategoryList
                PaginatableMediaList(
                    items: searchModel.mediaItems,
                    status: searchModel.mediaPaginationStatus,
                    toolOverlayPadding: false,
                    paginationRequest: searchModel.mediaPagination
                )


            }
            .id("all")
        case .categories:
            PaginatableCategoryList(
                items: searchModel.categoryItems,
                status: searchModel.categoryPaginationStatus,
                paginationRequest: searchModel.categoryPagination
            )
            .id("categories")
        case .images:
            PaginatableMediaList(
                items: searchModel.mediaItems,
                status: searchModel.mediaPaginationStatus,
                toolOverlayPadding: false,
                paginationRequest: searchModel.mediaPagination
            )
            .id("images")
        }
    }

    @ViewBuilder
    private var HorizontalCategoryList: some View {
        let items = searchModel.categoryResults?.categoryInfos ?? []

        if !items.isEmpty {
            ScrollView(.horizontal) {
                LazyHGrid(rows: [GridItem(), GridItem()]) {

                    ForEach(items) { categoryInfo in
                        CategoryTeaser(categoryInfo: categoryInfo)
                            .frame(width: 260)
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

                .frame(height: 400)
                .padding(.top, 50)
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }

    private var optionBar: some View {
        HStack {
            Menu {
                ForEach(SearchOrder.allCases, id: \.self) { order in
                    Button(action: { searchModel.setOrder(order) }) {
                        Label {
                            Text(order.localizedStringResource)
                        } icon: {
                            if order == searchModel.order {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label {
                    Text(searchModel.order.localizedStringResource)
                } icon: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(.regularMaterial, in: .capsule)
                .font(.footnote)
                .frame(minWidth: 100)
                .scenePadding(.horizontal)
                .padding(.vertical, 5)
                .padding(.top, isScrolledDown ? 5 : 0)
                .contentShape(.rect)
            }


            Spacer()

            //            Button {
            //
            //            } label: {
            //                Image(systemName: "square.grid.2x2")
            //                    .padding(.horizontal, 9)
            //                    .padding(.vertical, 9)
            //                    .background(.regularMaterial, in: .capsule)
            //                    .font(.footnote)
            //
            //            }
            //            .disabled(true)

        }
        .buttonStyle(.plain)
        .transition(
            .asymmetric(
                insertion: .opacity.animation(.default.speed(0.5)),
                removal: .opacity.combined(with: .offset(y: -10)))
        )
    }
}

#Preview(traits: .previewEnvironment) {
    NavigationView {
        SearchView()
    }
}
