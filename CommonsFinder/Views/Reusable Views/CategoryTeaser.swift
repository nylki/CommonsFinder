//
//  CategoryTeaser.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 07.07.25.
//

import NukeUI
import SwiftUI

struct CategoryTeaser: View {
    let categoryInfo: CategoryInfo

    /// withContextMenu=false should only be used, when a context menu is already applied
    /// it is false for the `preview` of `CategoryContextMenu` to avoid recursion.
    var withContextMenu: Bool = true

    var body: some View {
        let categoryTeaser = CategoryTeaserBase(categoryInfo: categoryInfo)

        if withContextMenu {
            categoryTeaser
                .contentShape(.contextMenuPreview, .rect(cornerRadius: 16))
                .modifier(CategoryContextMenu(item: categoryInfo))
        } else {
            categoryTeaser
        }
    }


}

private struct CategoryTeaserBase: View {
    let categoryInfo: CategoryInfo

    var body: some View {
        let backgroundImage = categoryInfo.base.thumbnailImage
        let hasBackgroundImage = backgroundImage != nil
        let label = categoryInfo.base.label ?? categoryInfo.base.commonsCategory

        NavigationLink(value: NavigationStackItem.wikidataItem(categoryInfo)) {
            HStack {
                VStack {
                    Spacer()

                    VStack(alignment: .leading) {
                        if let label {
                            Text(label)
                        }
                        if let description = categoryInfo.base.description {
                            Text(description)
                                .font(.caption)
                                .allowsTightening(true)
                        }
                    }
                    .shadow(color: hasBackgroundImage ? .black : .clear, radius: 2)
                    .shadow(color: .black.opacity(0.7), radius: 7)

                }
                .multilineTextAlignment(.leading)
                .foregroundStyle(Color.white)

                Spacer(minLength: 0)
            }
            .padding()
            .background {
                CategoryTeaserBackground(category: categoryInfo.base).scaledToFill()
            }
            .clipShape(.rect(cornerRadius: 16))
        }
        .frame(idealWidth: 260, idealHeight: 170)
    }
}

#Preview {
    ScrollView(.vertical) {
        LazyVStack {
            CategoryTeaser(categoryInfo: .init(.earth))
            CategoryTeaser(categoryInfo: .init(.earthNoImage))
            CategoryTeaser(categoryInfo: .init(.earthExtraLongLabel))
            CategoryTeaser(categoryInfo: .init(.testItemNoDesc))
            CategoryTeaser(categoryInfo: .init(.testItemNoLabel))
            CategoryTeaser(categoryInfo: .init(.randomItem(id: "random")))
        }
    }
    .scenePadding()
}
