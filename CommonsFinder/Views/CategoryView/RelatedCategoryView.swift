//
//  RelatedCategoryView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 13.03.25.
//

import FrameUp
import SwiftUI

struct RelatedCategoryView: View {
    let categories: [CategoryInfo]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columnCount: Int {
        if dynamicTypeSize.isAccessibilitySize {
            dynamicTypeSize >= .xLarge ? 1 : 2
        } else {
            2
        }
    }

    var body: some View {
        VMasonryLayout(columns: columnCount) {
            ForEach(categories, id: \.self) { subCategory in
                let navItem = NavigationStackItem.wikidataItem(subCategory)
                NavigationLink(value: navItem) {
                    let label = subCategory.base.commonsCategory ?? "-"
                    Text(label)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: 320 / Double(columnCount))
            }
        }
        .padding(.top, 5)
    }
}

#Preview(traits: .previewEnvironment) {
    RelatedCategoryView(categories: [
        .init(.init(commonsCategory: "foo")),
        .init(.init(commonsCategory: "bar")),
        .init(.init(commonsCategory: "Lake with a very long name and some more overflowing description")),
        .init(.init(commonsCategory: "Cities by Sound by Music")),
        .init(.init(commonsCategory: "Lake B")),
    ])
}
