//
//  ListItemView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 17.12.24.
//

import CommonsAPI
import NukeUI
import SwiftUI
import os.log

struct MediaFileListItem: View {
    let mediaFileInfo: MediaFileInfo
    let containerWidth: CGFloat
    var isImageLoadingAllowed = true

    @Environment(Navigation.self) private var navigationModel
    @Environment(AccountModel.self) private var account
    @Environment(\.appDatabase) private var appDatabase
    @Namespace private var navigationNamespace
    @Environment(\.locale) private var locale


    var body: some View {
        Button {
            navigationModel.viewFile(mediaFile: mediaFileInfo, namespace: navigationNamespace)
        } label: {
            label
        }
        .buttonStyle(MediaCardButtonStyle())
        .modifier(MediaFileContextMenu(mediaFileInfo: mediaFileInfo, namespace: navigationNamespace))
        .matchedTransitionSource(id: mediaFileInfo.id, in: navigationNamespace)
        // .clipShape is redundant here as its already defined in the ButtonStyle, but apparently
        // required, for the .zoom transition to properly settle back without hard corners
        .clipShape(.rect(cornerRadius: 16))
    }

    private func imageHeight(imageAspectRatio: Double = 1, containerWidth: Double) -> Double {
        let preferredAspect: Double = 3 / 2
        var preferredHeight = containerWidth / preferredAspect
        preferredHeight = (1 / imageAspectRatio) * containerWidth
        preferredHeight = min(450, max(110, preferredHeight))
        return preferredHeight.rounded(.towardZero)
    }

    @ViewBuilder
    private var label: some View {
        VStack(alignment: .leading) {
            let imageHeight = imageHeight(
                imageAspectRatio: mediaFileInfo.mediaFile.aspectRatio ?? 1,
                containerWidth: containerWidth
            )

            MediaFileThumbImage(mediaFileInfo, isImageLoadingAllowed: isImageLoadingAllowed)
                .frame(width: containerWidth, height: imageHeight)
                .clipped()

            Spacer()

            VStack {
                Text(mediaFileInfo.mediaFile.bestShortTitle)
            }
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .padding(11)
            .animation(.default, value: mediaFileInfo.mediaFile.bestShortTitle)
        }
    }
}

struct MediaCardButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.cardBackground)
            .clipShape(.rect(cornerRadius: 16))
            .contentShape([.contextMenuPreview, .interaction], .rect(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.default, value: configuration.isPressed)
    }
}


#Preview("Square", traits: .previewEnvironment) {
    LazyVStack {
        MediaFileListItem(mediaFileInfo: .makeRandomUploaded(id: "1234", .squareImage), containerWidth: 400)
    }
    .frame(width: 400)

}

#Preview("Vertical", traits: .previewEnvironment) {
    LazyVStack {
        MediaFileListItem(mediaFileInfo: .makeRandomUploaded(id: "1234", .verticalImage), containerWidth: 400)
    }
    .frame(width: 400)
}

#Preview("Panorama", traits: .previewEnvironment) {
    LazyVStack {
        MediaFileListItem(mediaFileInfo: .makeRandomUploaded(id: "1234", .horizontalImage), containerWidth: 400)
    }
    .frame(width: 400)
}
