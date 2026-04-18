//
//  MapSheetCategoryTeaser.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.03.25.
//

import CommonsAPI
import NukeUI
import SwiftUI

struct MapSheetCategoryTeaser: View {
    // needs a better type for previews and images?
    let item: CategoryInfo
    var size: WidthClass = .regular
    let isSelected: Bool
    var isInScrollView: Bool = true
    let namespace: Namespace.ID

    enum WidthClass {
        case regular
        case wide
    }

    @Environment(Navigation.self) private var navigation

    var body: some View {
        Button {
            navigation.viewCategory(item)
        } label: {
            CategoryTeaserContent(categoryInfo: item)
                .modifier(CategoryContextMenu(item: item, hiddenEntries: [.showOnMap]))
                .scrollTransition(
                    .interactive, axis: .horizontal,
                    transition: { view, phase in
                        view.scaleEffect(y: (phase == .identity || !isInScrollView) ? 1 : 0.9)

                    }
                )
                .padding(3)
                .overlay {
                    ContainerRelativeShape()
                        .stroke(isSelected ? Color.accent : .clear, lineWidth: 2)
                }
                .padding(3)
        }
        .containerRelativeFrame(.horizontal, count: 5, span: size == .regular ? 3 : 4, spacing: 0)
        .buttonStyle(CategoryTeaserButtonStyle())
        .animation(.default, value: isSelected)
    }

}

#Preview {
    @Previewable @Namespace var namespace

    VStack {
        Group {
            MapSheetCategoryTeaser(item: .randomItem(id: "1"), isSelected: false, namespace: namespace)
            MapSheetCategoryTeaser(item: .randomItem(id: "2"), isSelected: false, namespace: namespace)
            MapSheetCategoryTeaser(item: .init(.testItemNoDesc), isSelected: false, namespace: namespace)
            MapSheetCategoryTeaser(item: .init(.testItemNoLabel), isSelected: false, namespace: namespace)
            MapSheetCategoryTeaser(item: .randomItem(id: "3"), isSelected: true, namespace: namespace)
        }
        // simulates a simplified MapPopup height
        .frame(height: 160)

    }
    .padding()
    .background(Material.regular)

}
