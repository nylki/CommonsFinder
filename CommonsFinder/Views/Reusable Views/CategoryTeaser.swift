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
        let categoryTeaser = CategoryTeaserContent(categoryInfo: categoryInfo)
        let destination = NavigationStackItem.wikidataItem(categoryInfo)
        let view =
            NavigationLink(value: destination) {
                categoryTeaser.frame(idealWidth: 260, idealHeight: 170)
            }
            .buttonStyle(CategoryTeaserButtonStyle())


        if withContextMenu {
            view.modifier(CategoryContextMenu(item: categoryInfo))
        } else {
            view
        }
    }
}


struct CategoryTeaserContent: View {
    let categoryInfo: CategoryInfo
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let backgroundImage = categoryInfo.base.thumbnailImage
        let hasBackgroundImage = backgroundImage != nil
        let label = categoryInfo.base.label ?? categoryInfo.base.commonsCategory

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
                .foregroundStyle(Color.white)
                .shadow(color: hasBackgroundImage ? .black : .clear, radius: 2)
                .shadow(color: hasBackgroundImage ? .black.opacity(0.7) : .clear, radius: 7)

            }
            .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding()
        .background {
            CategoryTeaserBackground(category: categoryInfo.base)

        }
        .geometryGroup()
        .compositingGroup()
    }
}

struct CategoryTeaserButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape([.contextMenuPreview, .interaction], .rect(cornerRadius: 16))
            .clipShape(.containerRelative)
            .opacity(configuration.isPressed ? 0.5 : 1)
            .animation(.default, value: configuration.isPressed)
    }
}

#Preview(traits: .previewEnvironment) {
    ScrollView(.vertical) {
        LazyVStack {
            CategoryTeaser(categoryInfo: .init(.earth))
            CategoryTeaser(categoryInfo: .init(.earthNoImage))
            CategoryTeaser(categoryInfo: .init(.earthExtraLongLabel))
            CategoryTeaser(categoryInfo: .init(.testItemNoDesc))
            //            CategoryTeaser(categoryInfo: .init(.testItemNoLabel))
            CategoryTeaser(categoryInfo: .init(.randomItem(id: "random")))
        }
        .padding()
    }
    .scenePadding()
}
