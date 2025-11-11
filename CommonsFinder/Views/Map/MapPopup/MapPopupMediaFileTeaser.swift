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
    let onTap: () -> Void

    private let shape = RoundedRectangle(cornerRadius: 18)

    var body: some View {

        Button {
            onTap()
        } label: {
            imageView
        }
        .modifier(MediaFileContextMenu(mediaFileInfo: mediaFileInfo, namespace: namespace))
        .foregroundStyle(.primary)
        .tint(.primary)
        .animation(.default, value: isSelected)

    }

    private var imageView: some View {
        LazyImage(request: mediaFileInfo.thumbRequest, transaction: .init(animation: .linear)) { imageState in
            if let image = imageState.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(shape)

            } else {
                shape
                    .fill(Material.thick)
                    .aspectRatio(contentMode: .fill)
            }
        }
        //        .frame(width: isSelected && (mediaFileInfo.mediaFile.aspectRatio ?? 1) > 1 ? 220 : 160, height: 160)
        .frame(width: 160, height: 160)
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
