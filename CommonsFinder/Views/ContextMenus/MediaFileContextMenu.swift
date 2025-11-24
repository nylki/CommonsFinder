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
    var mediaFileInfo: MediaFileInfo?
    let namespace: Namespace.ID
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
                        Button("Open Details") {
                            navigation.viewFile(mediaFile: mediaFileInfo, namespace: namespace)
                        }
                        if mediaFileInfo.mediaFile.coordinate != nil {
                            Button("Show on Map", systemImage: "map", action: showOnMap)
                        }
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
                        ShareLink(item: mediaFileInfo.mediaFile.descriptionURL)
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
