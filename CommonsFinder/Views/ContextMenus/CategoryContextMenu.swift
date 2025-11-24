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
    @Environment(Navigation.self) private var navigation
    @Environment(MapModel.self) private var mapModel
    @Namespace private var namespace

    func body(content: Content) -> some View {
        content
            .contextMenu {
                VStack {
                    Button("Open Details") {
                        navigation.viewCategory(item)
                    }

                    if item.base.coordinate != nil {
                        Button("Show on Map") {
                            do {
                                try mapModel.showInCircle(item.base)
                                navigation.selectedTab = .map
                            } catch {
                                logger.error("Failed to show category on map \(error)")
                            }
                        }
                    }

                    Button(
                        item.isBookmarked ? "Remove Bookmark" : "Add Bookmark",
                        systemImage: item.isBookmarked ? "bookmark.fill" : "bookmark",
                        action: { updateBookmark(!item.isBookmarked) }
                    )

                    // TODO: open location in OrganicMaps / AppleMaps
                    CategoryLinkSection(item: item)
                }
            } preview: {
                CategoryTeaser(categoryInfo: item, withContextMenu: false)
                    .frame(width: 350, height: 250)

            }
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
