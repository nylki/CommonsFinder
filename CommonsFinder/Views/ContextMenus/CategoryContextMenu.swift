//
//  MediaFileContextMenu.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 27.03.25.
//

import CommonsAPI
import NukeUI
import SwiftUI
import os.log

struct CategoryContextMenu: ViewModifier {
    let item: CategoryInfo
    @Environment(\.appDatabase) private var appDatabase

    func body(content: Content) -> some View {
        content
            .contextMenu {
                VStack {
                    NavigationLink("Open Details", value: NavigationStackItem.wikidataItem(item))

                    Button(
                        item.isBookmarked ? "Remove Bookmark" : "Add Bookmark",
                        systemImage: item.isBookmarked ? "bookmark.fill" : "bookmark",
                        action: { updateBookmark(!item.isBookmarked) }
                    )

                    // TODO: open location in OrganicMaps / AppleMaps
                    CategoryLinkSection(item: item)
                }
            }
        //        preview: {
        //                VStack {
        //                    VStack {
        //                        if let label = item.base.label ?? item.base.commonsCategory {
        //                            Text(label)
        //                                .lineLimit(4)
        //                                .font(.title3)
        //                        }
        //                        if let desc = item.base.description {
        //                            Text(desc)
        //                                .lineLimit(4)
        //                                .font(.caption)
        //                        }
        //                    }
        //                    .padding()
        //
        //                    if let imageRequest = item.base.thumbnailImage {
        //                        LazyImage(request: imageRequest) {
        //                            if let image = $0.image {
        //                                image
        //                                    .resizable()
        //                                    .aspectRatio(contentMode: .fit)
        //                            }
        //                        }
        //                        .clipShape(.rect(cornerRadius: 16))
        //                        .padding()
        //                    }
        //                }
        //                .frame(minHeight: 100)
        //
        //
        //                //                LazyImage(request: mediaFileInfo.thumbRequest) {
        //                //                    if let image = $0.image {
        //                //                        image.resizable()
        //                //                    }
        //                //                }
        //            }
    }

    private func updateBookmark(_ value: Bool) {
        do {
            _ = try appDatabase.updateBookmark(item, bookmark: value)
        } catch {
            logger.error("Failed to update bookmark on wiki item \(item.id): \(error)")
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
    .modifier(CategoryContextMenu(item: .randomItem(id: "1")))
}
