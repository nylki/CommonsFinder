//
//  MediaFileContextMenu.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 27.03.25.
//

import NukeUI
import SwiftUI
import os.log

struct MediaFileContextMenu: ViewModifier {
    private var mediaFileInfo: MediaFileInfo?
    private let namespace: Namespace.ID
    private let shownEntries: ContextMenuEntries

    init(mediaFileInfo: MediaFileInfo?, namespace: Namespace.ID) {
        self.mediaFileInfo = mediaFileInfo
        self.shownEntries = .all
        self.namespace = namespace
    }

    init(mediaFileInfo: MediaFileInfo?, shownEntries: ContextMenuEntries, namespace: Namespace.ID) {
        self.mediaFileInfo = mediaFileInfo
        self.shownEntries = shownEntries
        self.namespace = namespace
    }

    init(mediaFileInfo: MediaFileInfo?, hiddenEntries: ContextMenuEntries, namespace: Namespace.ID) {
        self.mediaFileInfo = mediaFileInfo
        self.shownEntries = .all.subtracting(hiddenEntries)
        self.namespace = namespace
    }

    @Environment(\.appDatabase) private var appDatabase
    @Environment(Navigation.self) private var navigation
    @Environment(MapModel.self) private var mapModel

    private func showOnMap() {
        guard let mediaFile = mediaFileInfo?.mediaFile else { return }
        do {
            try mapModel.showInCircle(mediaFile)
            navigation.selectedTab = .map
        } catch {
            logger.error("Failed to show category on map \(error)")
        }
    }

    func body(content: Content) -> some View {
        content
            .contextMenu {
                if let mediaFileInfo {
                    VStack {
                        if shownEntries.contains(.openDetails) {
                            Button("Open Details") {
                                navigation.viewFile(mediaFile: mediaFileInfo, namespace: namespace)
                            }
                        }

                        if shownEntries.contains(.showOnMap), mediaFileInfo.mediaFile.coordinate != nil {
                            Button("Show on Map", systemImage: "map", action: showOnMap)
                        }

                        if shownEntries.contains(.bookmark) {
                            Button(
                                mediaFileInfo.isBookmarked ? "Remove Bookmark" : "Add Bookmark",
                                systemImage: mediaFileInfo.isBookmarked ? "bookmark.fill" : "bookmark"
                            ) {
                                do {
                                    _ = try appDatabase.updateBookmark(mediaFileInfo, bookmark: !mediaFileInfo.isBookmarked)
                                } catch {
                                    logger.error("Failed to update bookmark on \(mediaFileInfo.mediaFile.name): \(error)")
                                }
                            }
                        }

                        if shownEntries.contains(.linkSection) {
                            ShareLink(item: mediaFileInfo.mediaFile.descriptionURL)
                        }
                    }
                }

            } preview: {
                LazyImage(request: mediaFileInfo?.thumbRequest) {
                    if let image = $0.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        if let mediaFile = mediaFileInfo?.mediaFile {
                            Color.clear.frame(
                                width: Double(mediaFile.width ?? 256),
                                height: Double(mediaFile.height ?? 256)
                            )
                        }

                    }
                }
            }
    }
}

extension MediaFileContextMenu {
    struct ContextMenuEntries: OptionSet {
        let rawValue: Int
        static let openDetails = Self(rawValue: 1 << 0)
        static let showOnMap = Self(rawValue: 1 << 1)
        static let bookmark = Self(rawValue: 1 << 2)
        static let linkSection = Self(rawValue: 1 << 3)

        static var all: Self {
            [.openDetails, .showOnMap, .bookmark, .linkSection]
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
    .modifier(MediaFileContextMenu(mediaFileInfo: mediaFileInfo, namespace: namespace))
}
