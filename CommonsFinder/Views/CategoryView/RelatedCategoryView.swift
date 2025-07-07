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
    var body: some View {
        VMasonryLayout(columns: 2) {
            ForEach(categories, id: \.self) { subCategory in
                let navItem = NavigationStackItem.wikidataItem(subCategory)
                NavigationLink(value: navItem) {
                    let label = subCategory.base.commonsCategory ?? "-"
                    Text(label)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: 150)
                        .lineLimit(3)
                }
                .buttonStyle(.bordered)
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
