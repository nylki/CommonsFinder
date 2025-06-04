//
//  MapPopupMediaItem.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.03.25.
//

import FrameUp
import NukeUI
import SwiftUI

struct MapPopupMediaItem: View {
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
                            .clipShape(.rect(cornerRadius: 16))

                    } else {
                        Rectangle()
                            .fill(Material.thick)
                            .aspectRatio(contentMode: .fill)
                            .clipShape(.rect(cornerRadius: 16))
                    }
                }
            }
            .frame(width: height, height: height)
            .clipShape(.rect(cornerRadius: 16))
            .contentShape([.contextMenuPreview, .interaction], .rect(cornerRadius: 16))
            .geometryGroup()
            .matchedTransitionSource(id: mediaFileInfo.id, in: namespace)
            .padding(2)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18).stroke(Color.accent, lineWidth: 1)
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
        MapPopupMediaItem(namespace: namespace, mediaFileInfo: .makeRandomUploaded(id: "1", .squareImage), isSelected: false)
        MapPopupMediaItem(namespace: namespace, mediaFileInfo: .makeRandomUploaded(id: "2", .horizontalImage), isSelected: true)
        MapPopupMediaItem(namespace: namespace, mediaFileInfo: .makeRandomUploaded(id: "3", .verticalImage), isSelected: false)
    }
    .frame(height: 160)
}
