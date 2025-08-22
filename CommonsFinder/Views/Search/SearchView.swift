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
                ProgressView().progressViewStyle(.circular)
            } else {
                PaginatableMediaList(
                    items: searchModel.items,
                    status: searchModel.paginationStatus,
                    toolOverlayPadding: true,
                    paginationRequest: searchModel.paginate
                )
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
                    if isOptionBarVisible { optionBar }
                }
                .onChange(of: searchModel.searchFieldFocusTrigger) {
                    isSearchFieldFocused = true
                }
            }
        }
        .animation(.default, value: searchModel.isSearching)
        .searchable(
            text: $searchModel.bindableSearchText,
            prompt: "Search on Wikimedia Commons"
        )
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
        .scenePadding(.horizontal)
        .padding(.top, isScrolledDown ? 10 : 0)
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
