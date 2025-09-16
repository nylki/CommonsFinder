//
//  MapPopupMediaFileTeaser.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.03.25.
//

import FrameUp
import NukeUI
import SwiftUI

struct MapPopupMediaFileTeaser: View {
    let namespace: Namespace.ID
    let mediaFileInfo: MediaFileInfo
    let isSelected: Bool


    var body: some View {
        HeightReader(alignment: .center) { height in

            NavigationLink(value: NavigationStackItem.viewFile(mediaFileInfo, namespace: namespace)) {
                LazyImage(request: mediaFileInfo.thumbRequest, transaction: .init(animation: .linear)) { imageState in
                    if let image = imageState.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(.containerRelative)

                    } else {
                        ContainerRelativeShape()
                            .fill(Material.thick)
                            .aspectRatio(contentMode: .fill)
                    }
                }
            }
            .frame(width: height, height: height)
            .clipShape(.containerRelative)
            .contentShape([.contextMenuPreview, .interaction], .containerRelative)
            .geometryGroup()
            .matchedTransitionSource(id: mediaFileInfo.id, in: namespace)
            .padding(2)
            .overlay {
                if isSelected {
                    ContainerRelativeShape()
                        .stroke(Color.accent, lineWidth: 1)
                }
            }
            .padding(2)
        }
        .modifier(MediaFileContextMenu(mediaFileInfo: mediaFileInfo, namespace: namespace))
        .animation(.default, value: isSelected)

    }
}

#Preview("MapPopupMediaItem") {
    @Previewable @Namespace var namespace
    HStack {
        MapPopupMediaFileTeaser(namespace: namespace, mediaFileInfo: .makeRandomUploaded(id: "1", .squareImage), isSelected: false)
        MapPopupMediaFileTeaser(namespace: namespace, mediaFileInfo: .makeRandomUploaded(id: "2", .horizontalImage), isSelected: true)
        MapPopupMediaFileTeaser(namespace: namespace, mediaFileInfo: .makeRandomUploaded(id: "3", .verticalImage), isSelected: false)
    }
    .frame(height: 160)
}
