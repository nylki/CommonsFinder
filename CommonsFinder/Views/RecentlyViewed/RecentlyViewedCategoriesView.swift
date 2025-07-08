//
//  RecentlyViewedCategoriesView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 06.07.25.
//

import GRDB
import SwiftUI
import os.log

struct RecentlyViewedCategoriesView: View {
    @State private var categories: [CategoryInfo]?
    @State private var observationTask: Task<Void, Never>?

    @Environment(\.appDatabase) private var appDatabase
    @Namespace private var namespace

    var body: some View {
        ScrollView(.vertical) {
            if let categories {
                if categories.isEmpty {
                    ContentUnavailableView(
                        "No recently viewed categories",
                        image: "photo.stack",
                        description: Text("You will find a history of your previously viewed categories here.")
                    )
                } else {
                    LazyVStack(spacing: 20) {
                        ForEach(categories) { categoryInfo in
                            CategoryTeaser(categoryInfo: categoryInfo)
                                .frame(height: 185)
                        }
                    }
                    .compositingGroup()
                    .scenePadding()
                    .safeAreaPadding(.trailing)
                    .shadow(color: .black.opacity(0.15), radius: 10)
                }
            }
        }
        .navigationTitle("Recently Viewed")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard observationTask == nil else { return }

            observationTask?.cancel()
            observationTask = Task<Void, Never> {
                do {
                    categories = try appDatabase.fetchRecentlyViewedCategoryInfos(order: .desc)
                } catch {
                    logger.error("Failed to observe categoryInfos \(error)")
                }
            }
        }
    }
}

#Preview {
    RecentlyViewedCategoriesView()
}
