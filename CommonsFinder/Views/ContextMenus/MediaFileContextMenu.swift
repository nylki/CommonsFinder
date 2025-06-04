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
    let mediaFileInfo: MediaFileInfo
    let namespace: Namespace.ID
    func body(content: Content) -> some View {
        content
            .contextMenu {
                VStack {
                    let navItem = NavigationStackItem.viewFile(mediaFileInfo, namespace: namespace)
                    NavigationLink("Open Details", value: navItem)
                    ShareLink(item: mediaFileInfo.mediaFile.descriptionURL)
                }
            } preview: {
                LazyImage(request: mediaFileInfo.thumbRequest) {
                    if let image = $0.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Color.clear.frame(
                            width: mediaFileInfo.mediaFile.width ?? 256,
                            height: mediaFileInfo.mediaFile.height ?? 256
                        )
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
