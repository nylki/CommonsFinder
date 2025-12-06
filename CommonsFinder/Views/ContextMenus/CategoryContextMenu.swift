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
    private let item: CategoryInfo
    private let shownEntries: ContextMenuEntries

    init(item: CategoryInfo) {
        self.item = item
        self.shownEntries = .all
    }

    init(item: CategoryInfo, shownEntries: ContextMenuEntries) {
        self.item = item
        self.shownEntries = shownEntries
    }

    init(item: CategoryInfo, hiddenEntries: ContextMenuEntries) {
        self.item = item
        self.shownEntries = .all.subtracting(hiddenEntries)
    }

    @Environment(\.appDatabase) private var appDatabase
    @Environment(Navigation.self) private var navigation
    @Environment(MapModel.self) private var mapModel
    @Namespace private var namespace

    func body(content: Content) -> some View {
        content
            .contextMenu {
                VStack {

                    if shownEntries.contains(.openDetails) {
                        Button("Open Details", systemImage: "square.text.square") {
                            navigation.viewCategory(item)
                        }
                    }

                    if shownEntries.contains(.showOnMap), item.base.coordinate != nil {
                        Button("Show on Map", systemImage: "map") {
                            navigation.showOnMap(category: item.base, mapModel: mapModel)
                        }
                    }

                    if shownEntries.contains(.bookmark) {
                        Button(
                            item.isBookmarked ? "Remove Bookmark" : "Add Bookmark",
                            systemImage: item.isBookmarked ? "bookmark.fill" : "bookmark",
                            action: { updateBookmark(!item.isBookmarked) }
                        )
                    }

                    Divider()

                    if shownEntries.contains(.newImage) {
                        Button("Add Image", systemImage: "plus") {
                            let newDraftOptions = NewDraftOptions(tag: TagItem(item.base, pickedUsages: [.category, .depict]))
                            navigation.openNewDraft(options: newDraftOptions)
                        }
                    }

                    if shownEntries.contains(.linkSection) {
                        // TODO: open location in OrganicMaps / AppleMaps
                        CategoryLinkSection(item: item)
                    }
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

extension CategoryContextMenu {
    struct ContextMenuEntries: OptionSet {
        let rawValue: Int
        static let openDetails = Self(rawValue: 1 << 0)
        static let showOnMap = Self(rawValue: 1 << 1)
        static let bookmark = Self(rawValue: 1 << 2)
        static let linkSection = Self(rawValue: 1 << 3)
        static let newImage = Self(rawValue: 1 << 4)

        static var all: Self {
            [.openDetails, .showOnMap, .bookmark, .linkSection, .newImage]
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
