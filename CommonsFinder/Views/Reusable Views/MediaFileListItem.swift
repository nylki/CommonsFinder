//
//  ListItemView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 17.12.24.
//

import CommonsAPI
import FrameUp
import NukeUI
import SwiftUI
import os.log

struct MediaFileListItem: View {
    let mediaFileInfo: MediaFileInfo

    @Environment(Navigation.self) private var navigationModel
    @Environment(AccountModel.self) private var account
    @Environment(\.appDatabase) private var appDatabase
    @Namespace private var navigationNamespace
    @Environment(\.locale) private var locale

    private var captionOrName: String {
        let captions = mediaFileInfo.mediaFile.captions

        return
            if let preferredCaption = captions.first(where: { $0.languageCode == locale.wikiLanguageCodeIdentifier })
        {
            preferredCaption.string
        } else if let description = mediaFileInfo.mediaFile.attributedStringDescription?.characters {
            String(description)
        } else if let anyCaption = captions.first {
            anyCaption.string
        } else {
            mediaFileInfo.mediaFile.displayName
        }
    }


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

    private func imageHeight(containerWidth: Double) -> Double {
        let imageAspect = mediaFileInfo.mediaFile.aspectRatio ?? 1
        let preferredAspect: Double = 3 / 2
        let preferredHeight = containerWidth / preferredAspect
        var height = preferredHeight
        height = (1 / imageAspect) * containerWidth
        return min(450, max(110, height))
    }

    private var label: some View {
        VStack(alignment: .leading) {
            imageView

            Spacer()

            VStack {
                Text(captionOrName)
            }
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .padding(11)
            .animation(.default, value: captionOrName)
        }
    }

    @ViewBuilder
    private var imageView: some View {
        WidthReader { width in
            let transaction = Transaction(animation: .linear)
            LazyImage(
                request: mediaFileInfo.thumbRequest,
                transaction: transaction
            ) { phase in
                ZStack {
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)

                    } else {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                }
                .frame(
                    width: width,
                    height: imageHeight(containerWidth: width)
                )
                .clipped()

            }
            .frame(
                width: width,
                height: imageHeight(containerWidth: width)
            )
        }
        .clipped()
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
        MediaFileListItem(mediaFileInfo: .makeRandomUploaded(id: "1234", .squareImage))
    }

}

#Preview("Vertical", traits: .previewEnvironment) {
    LazyVStack {
        MediaFileListItem(mediaFileInfo: .makeRandomUploaded(id: "1234", .verticalImage))
    }
}

#Preview("Panorama", traits: .previewEnvironment) {
    LazyVStack {
        MediaFileListItem(mediaFileInfo: .makeRandomUploaded(id: "1234", .horizontalImage))
    }
}
