//
//  File.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 27.03.26.
//

import SwiftUI

struct HorizontalCategoryList: View {
    let model: PaginatableCategories

    init(model: some PaginatableCategories) {
        self.model = model
    }

    var body: some View {
        let items = model.categoryInfos
        let hasCategoriesLoaded = !items.isEmpty
        let isLoadingCategories = model.status == .isPaginating
        ZStack {
            if hasCategoriesLoaded {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 20) {
                        ForEach(items) { categoryInfo in
                            CategoryTeaser(categoryInfo: categoryInfo)
                                .frame(width: 260, height: 200)
                                .onScrollVisibilityChange { visible in
                                    guard visible else { return }
                                    let threshold = min(items.count - 1, max(0, items.count - 5))
                                    guard threshold > 0 else { return }
                                    let thresholdItem = items[threshold]

                                    if categoryInfo == thresholdItem {
                                        model.paginate()
                                    }
                                }
                        }

                        if model.status == .isPaginating {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .frame(width: 260, height: 300)
                        }
                    }
                    .scrollTargetLayout()
                    .scenePadding(.horizontal)
                    .padding(.bottom)
                    .animation(.default, value: items)
                    .containerShape(.rect(cornerRadius: 16))
                }
                .scrollTargetBehavior(.viewAligned)
            } else if isLoadingCategories {
                ProgressView()
                    .frame(height: 200)
                    .containerRelativeFrame(.horizontal)
            }
        }
        .animation(.default, value: hasCategoriesLoaded)
        .animation(.default, value: model.status)
        .animation(.default, value: model.rawCount)
        .compositingGroup()
        .shadow(color: .black.opacity(0.1), radius: 10)
    }
}

#Preview(traits: .previewEnvironment) {

    HorizontalCategoryList(
        model: .init(
            previewAppDatabase: .shared,
            searchTargets: .all,
            prefilledCategories: [
                .randomItem(id: "1"), .randomItem(id: "3"), .randomItem(id: "4"), .randomItem(id: "5"),
            ]
        )

    )
}
