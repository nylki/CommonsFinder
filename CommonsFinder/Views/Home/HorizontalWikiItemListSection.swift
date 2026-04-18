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
                            .labelStyle(SecondaryIconTrailingLabelStyle())
                            .font(.title3)
                            .bold()
                    }
                    .tint(.primary)
                    Spacer()
                }
            }
        }
        .safeAreaPadding(.leading)
    }

    private var horizontalList: some View {
        ScrollView(.horizontal) {
            LazyHStack {
                ForEach(items.prefix(50)) { item in
                    CategoryTeaser(categoryInfo: item)
                        .frame(width: 260, height: 185)
                }
            }
            .containerShape(.rect(cornerRadius: 16))
            .scrollTargetLayout()
            .padding([.vertical, .trailing], 5)
            .padding(.leading, 0)
            .scenePadding(.bottom)

        }
        .scrollTargetBehavior(.viewAligned)
        .animation(.default, value: items)
        .compositingGroup()
        .shadow(color: .black.opacity(0.15), radius: 10)
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
