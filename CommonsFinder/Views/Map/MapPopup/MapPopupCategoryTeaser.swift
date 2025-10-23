//
//  MapPopupCategoryTeaser.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.03.25.
//

import CommonsAPI
import NukeUI
import SwiftUI

struct MapPopupCategoryTeaser: View {
    // needs a better type for previews and images?
    let item: CategoryInfo
    let isSelected: Bool
    let namespace: Namespace.ID

    @Environment(Navigation.self) private var navigation

    var body: some View {
        let hasBackgroundImage = item.base.thumbnailImage != nil

        Button {
            navigation.viewCategory(item)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Spacer()
                    if let label = item.base.label ?? item.base.commonsCategory {
                        Text(label)
                    }
                    if let description = item.base.description {
                        Text(description)
                            .font(.caption)
                            .allowsTightening(true)
                    }
                }
                .multilineTextAlignment(.leading)
                .foregroundStyle(Color.white)

                Spacer(minLength: 0)
            }
            .shadow(color: hasBackgroundImage ? .black : .clear, radius: 2)
            .shadow(color: .black.opacity(0.7), radius: 7)
            .padding()
            .containerRelativeFrame(.horizontal, count: 5, span: 3, spacing: 0)
            .frame(minHeight: 0, maxHeight: .infinity)
            .background {
                Color(.emptyWikiItemBackground)
                    .overlay {
                        if let imageRequest = item.base.thumbnailImage {
                            LazyImage(request: imageRequest, transaction: .init(animation: .linear)) { imageState in
                                if let image = imageState.image {
                                    image.resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .scaledToFill()
                                } else {
                                    Color.clear
                                }
                            }
                        }
                    }
                    .overlay {
                        if item.base.thumbnailImage != nil {
                            LinearGradient(
                                stops: [
                                    .init(color: .init(white: 0, opacity: 0), location: 0),
                                    .init(color: .init(white: 0, opacity: 0.1), location: 0.35),
                                    .init(color: .init(white: 0, opacity: 0.2), location: 0.5),
                                    .init(color: .init(white: 0, opacity: 0.8), location: 1),
                                ], startPoint: .top, endPoint: .bottom)
                        }
                    }

            }
            .clipShape(.containerRelative)
            .contentShape([.contextMenuPreview, .interaction], .containerRelative)
            .modifier(CategoryContextMenu(item: item))
            .padding(2)
            .overlay {
                if isSelected {
                    ContainerRelativeShape()
                        .stroke(Color.accent, lineWidth: 1)
                }
            }
            .padding(2)
        }
        .animation(.default, value: isSelected)
    }

}

#Preview {
    @Previewable @Namespace var namespace

    VStack {
        Group {
            MapPopupCategoryTeaser(item: .randomItem(id: "1"), isSelected: false, namespace: namespace)
            MapPopupCategoryTeaser(item: .randomItem(id: "2"), isSelected: false, namespace: namespace)
            MapPopupCategoryTeaser(item: .init(.testItemNoDesc), isSelected: false, namespace: namespace)
            MapPopupCategoryTeaser(item: .init(.testItemNoLabel), isSelected: false, namespace: namespace)
            MapPopupCategoryTeaser(item: .randomItem(id: "3"), isSelected: true, namespace: namespace)
        }
        // simulates a simplified MapPopup height
        .frame(height: 160)

    }
    .padding()
    .background(Material.regular)

}
