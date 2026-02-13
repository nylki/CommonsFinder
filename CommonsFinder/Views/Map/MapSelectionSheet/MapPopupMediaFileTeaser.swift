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
    var size: WidthClass = .regular
    let isSelected: Bool
    let onTap: () -> Void

    enum WidthClass {
        case regular
        case wide
    }

    private let shape = ContainerRelativeShape()

    var body: some View {

        Button {
            onTap()
        } label: {
            imageView
        }
        .modifier(MediaFileContextMenu(mediaFileInfo: mediaFileInfo, hiddenEntries: [.showOnMap], namespace: namespace))
        .foregroundStyle(.primary)
        .tint(.primary)
        .animation(.default, value: isSelected)

    }

    private var imageView: some View {
        MediaFileThumbImage(mediaFileImage: mediaFileInfo)
            //        .frame(width: isSelected && (mediaFileInfo.mediaFile.aspectRatio ?? 1) > 1 ? 220 : 160, height: 160)
            .frame(width: size == .wide ? 250 : 160, height: 160)
            .clipShape(shape)
            .contentShape([.contextMenuPreview, .interaction], shape)
            .geometryGroup()
            .scrollTransition(
                .interactive, axis: .horizontal,
                transition: { view, phase in
                    view.scaleEffect(y: phase == .identity ? 1 : 0.9)
                }
            )
            .matchedTransitionSource(id: mediaFileInfo.id, in: namespace)
            .padding(3)
            .overlay {
                shape
                    .stroke(isSelected ? Color.accent : .clear, lineWidth: 2)
            }
            .padding(3)
    }
}

#Preview("MapPopupMediaItem", traits: .previewEnvironment) {
    @Previewable @Namespace var namespace
    ScrollView(.horizontal) {
        HStack {
            MapPopupMediaFileTeaser(namespace: namespace, mediaFileInfo: .makeRandomUploaded(id: "1", .squareImage), isSelected: false) {}
            MapPopupMediaFileTeaser(namespace: namespace, mediaFileInfo: .makeRandomUploaded(id: "2", .horizontalImage), isSelected: true) {}
            MapPopupMediaFileTeaser(namespace: namespace, mediaFileInfo: .makeRandomUploaded(id: "3", .verticalImage), isSelected: false) {}
        }
        .frame(height: 160)
    }
}
