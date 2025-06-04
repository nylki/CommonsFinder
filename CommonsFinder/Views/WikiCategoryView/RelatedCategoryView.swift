//
//  RelatedCategoryView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 13.03.25.
//

import FrameUp
import SwiftUI

struct RelatedCategoryView: View {
    let categories: [String]
    var body: some View {
        VMasonryLayout(columns: 2) {
            ForEach(categories, id: \.self) { subCategory in
                let navItem = NavigationStackItem.category(title: subCategory)
                NavigationLink(value: navItem) {
                    Text(subCategory)
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
        "foo", "bar",
        "Lake with a very long name and some more overflowing description",
        "Cities by Sound by Music", "Lake B",
    ])
}
