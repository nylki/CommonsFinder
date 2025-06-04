//
//  MapPopupWikiItem.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.03.25.
//

import CommonsAPI
import NukeUI
import SwiftUI

struct MapPopupWikiItem: View {
    // needs a better type for previews and images?
    let item: WikidataItem
    let isSelected: Bool
    let namespace: Namespace.ID

    var body: some View {
        let hasBackgroundImage = item.thumbnailImage != nil

        NavigationLink(value: NavigationStackItem.wikiItem(id: item.id)) {
            HStack {
                VStack(alignment: .leading) {
                    Spacer()
                    if let label = item.label {
                        Text(label)
                    }
                    if let description = item.description {
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
            .padding(10)
            .containerRelativeFrame(.horizontal, count: 5, span: 3, spacing: 0)
            .frame(minHeight: 0, maxHeight: .infinity)
            .background {
                Color(.emptyWikiItemBackground)
                    .overlay {
                        if let imageRequest = item.thumbnailImage {
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
                        if item.thumbnailImage != nil {
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
            .clipShape(.rect(cornerRadius: 10))
            .padding(2)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12).stroke(Color.accent, lineWidth: 1)
                }
            }
            .padding(2)
        }
        .modifier(WikiCategoryContextMenu(wikidataItem: item))
        .animation(.default, value: isSelected)
    }

}

#Preview {
    @Previewable @Namespace var namespace

    VStack {
        Group {
            MapPopupWikiItem(item: .randomItem(id: "1"), isSelected: false, namespace: namespace)
            MapPopupWikiItem(item: .randomItem(id: "2"), isSelected: false, namespace: namespace)
            MapPopupWikiItem(item: .testItemNoDesc, isSelected: false, namespace: namespace)
            MapPopupWikiItem(item: .testItemNoLabel, isSelected: false, namespace: namespace)
            MapPopupWikiItem(item: .randomItem(id: "3"), isSelected: true, namespace: namespace)
        }
        // simulates a simplified MapPopup height
        .frame(height: 160)

    }
    .padding()
    .background(Material.regular)

}
