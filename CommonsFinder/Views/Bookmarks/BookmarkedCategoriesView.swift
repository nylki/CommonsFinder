//
//  BookmarkedCategoriesView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 24.06.25.
//


import GRDBQuery
import SwiftUI
import os.log

struct BookmarkedCategoriesView: View {
    @Query(AllBookmarksWikiItemRequest()) private var categoryInfos

    @Namespace private var namespace

    var body: some View {
        if categoryInfos.isEmpty {
            BookmarksUnavailableView()
        } else {
            ScrollView(.vertical) {
                Text("This View is Work-in-Progress")
                LazyVStack(spacing: 20) {
                    ForEach(categoryInfos) { categoryInfo in
                        CategoryListItem(
                            categoryInfo: categoryInfo,
                            namespace: namespace
                        )
                    }
                }
                .compositingGroup()
                .scenePadding()
                .safeAreaPadding(.trailing)
                .shadow(color: .black.opacity(0.15), radius: 10)

            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
        }

    }
}

#Preview {
    BookmarkedCategoriesView()
}
