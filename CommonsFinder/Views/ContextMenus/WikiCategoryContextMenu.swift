//
//  MediaFileContextMenu.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 27.03.25.
//

import CommonsAPI
import NukeUI
import SwiftUI

struct WikiCategoryContextMenu: ViewModifier {
    let wikidataItem: WikidataItem

    func body(content: Content) -> some View {
        content
            .contextMenu {
                VStack {
                    NavigationLink("Open Details", value: NavigationStackItem.wikiItem(id: wikidataItem.id))

                    // TODO: open location in OrganicMaps / AppleMaps
                    WikiCategoryLinkSection(
                        wikidataItem: wikidataItem,
                        categoryName: wikidataItem.commonsCategory
                    )
                }
            } preview: {
                VStack {
                    VStack {
                        if let label = wikidataItem.label {
                            Text(label)
                                .lineLimit(4)
                                .font(.title3)
                        }
                        if let desc = wikidataItem.description {
                            Text(desc)
                                .lineLimit(4)
                                .font(.caption)
                        }
                    }
                    .padding()

                    if let imageRequest = wikidataItem.thumbnailImage {
                        LazyImage(request: imageRequest) {
                            if let image = $0.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            }
                        }
                        .clipShape(.rect(cornerRadius: 16))
                        .padding()
                    }
                }
                .frame(minHeight: 100)


                //                LazyImage(request: mediaFileInfo.thumbRequest) {
                //                    if let image = $0.image {
                //                        image.resizable()
                //                    }
                //                }
            }
    }
}

#Preview {
    @Previewable @Namespace var namespace
    let mediaFileInfo = MediaFileInfo.makeRandomUploaded(id: "1", .verticalImage)

    LazyImage(request: mediaFileInfo.thumbRequest) {
        if let image = $0.image {
            image.resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 150, height: 150)
                .clipShape(.circle)

        }
    }
    .overlay {
        Text("Long-Press me!")
            .font(.title)
            .foregroundStyle(.white)
            .bold()
    }
    .contentShape([.contextMenuPreview, .interaction], .circle)
    .modifier(WikiCategoryContextMenu(wikidataItem: .randomItem(id: "1")))
}
