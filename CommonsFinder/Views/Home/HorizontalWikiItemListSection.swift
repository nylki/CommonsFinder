//
//  HorizontalWikiItemListSection.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 19.06.25.
//

import SwiftUI

struct HorizontalWikiItemListSection: View {
    let label: LocalizedStringKey
    let destination: NavigationStackItem
    let items: [CategoryInfo]

    @Namespace private var namespace

    var body: some View {
        VStack {
            Section {
                horizontalList
            } header: {
                HStack {
                    NavigationLink(value: destination) {
                        Label(label, systemImage: "chevron.right")
                            .labelStyle(IconTrailingLabelStyle())
                    }
                    Spacer()
                }
                .scenePadding(.leading)
            }
        }
        .safeAreaPadding(.leading)
    }

    private var horizontalList: some View {
        ScrollView(.horizontal) {
            LazyHStack {
                ForEach(items.prefix(50)) { item in
                    NavigationLink(value: NavigationStackItem.wikidataItem(item)) {
                        // FIXME: do not re-use map item view, unless it is more generic without selection!
                        MapPopupCategoryTeaser(item: item, isSelected: false, namespace: namespace)
                    }
                    .matchedTransitionSource(id: item.id, in: namespace)
                    .contentShape([.contextMenuPreview, .interaction], .rect(cornerRadius: 16))
                    .modifier(CategoryContextMenu(item: item))
                }
            }
            .scrollTargetLayout()
            .frame(height: 128)
            .padding([.vertical, .trailing], 5)
            .padding(.leading, 0)
            .scenePadding(.bottom)
        }
        .scrollTargetBehavior(.viewAligned)


        .animation(.default, value: items)
    }
}

#Preview {
    HorizontalWikiItemListSection(
        label: "some items", destination: .settings,
        items: [
            .init(.earth),
            .init(.earthExtraLongLabel),
            .init(.testItemNoDesc),
            .init(.testItemNoDesc),
        ])
}
