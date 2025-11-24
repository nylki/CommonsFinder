//
//  HorizontalCategoryMapList.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 18.11.25.
//

import SwiftUI

struct HorizontalCategoryMapList: View {
    @Binding var focusedItem: ScrollPosition
    let categories: [CategoryInfo]
    let mapAnimationNamespace: Namespace.ID

    @Environment(Navigation.self) private var navigation

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack {
                ForEach(categories) { item in
                    let isSelected = item.id == focusedItem.viewID(type: String.self)
                    MapSheetCategoryTeaser(item: item, isSelected: isSelected, namespace: mapAnimationNamespace)
                }
            }
            .containerShape(ViewConstants.mapSheetContainerShape)
            .frame(minWidth: 100)
            .safeAreaPadding(.horizontal, 120)
            .frame(height: 180)
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .clipped()
        .scrollPosition($focusedItem, anchor: .center)
        .sensoryFeedback(
            .selection, trigger: focusedItem,
            condition: { oldValue, newValue in
                if oldValue.viewID == nil { return false }
                return newValue.viewID != nil
            }
        )
        .onChange(of: categories, initial: true) {
            // set scroll position to first image if not yet
            if focusedItem.viewID == nil, let firstItem = categories.first {
                focusedItem = .init(id: firstItem.id)
            }
        }
    }
}
