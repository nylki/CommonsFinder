//
//  HorizontalFileListSection.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 09.01.25.
//

import NukeUI
import SwiftUI

struct HorizontalFileListSection: View {
    let label: LocalizedStringKey
    let destination: NavigationStackItem
    let mediaFileInfos: [MediaFileInfo]

    @Namespace private var namespace

    var body: some View {
        VStack {
            Section {
                horizontalList
            } header: {
                HStack {
                    NavigationLink(value: destination) {
                        Label(label, systemImage: "chevron.right")
                            .labelStyle(IconTrailingLabelStyle())
                            .font(.title3)
                            .bold()
                    }
                    .tint(.primary)
                    Spacer()
                }
            }
        }
        .safeAreaPadding(.leading)
    }

    private var horizontalList: some View {
        ScrollView(.horizontal) {
            LazyHStack {
                ForEach(mediaFileInfos.prefix(50)) { mediaFileInfo in
                    let accessibilityLabel = Text(mediaFileInfo.mediaFile.localizedDisplayCaption ?? mediaFileInfo.mediaFile.displayName)

                    let navItem = NavigationStackItem.viewFile(
                        mediaFileInfo, namespace: namespace
                    )
                    NavigationLink(value: navItem) {
                        imageView(mediaFileInfo)
                    }
                    .clipShape(.rect(cornerRadius: 16))
                    .contentShape([.contextMenuPreview, .interaction], .rect(cornerRadius: 16))
                    .matchedTransitionSource(id: mediaFileInfo.id, in: namespace) {
                        $0.clipShape(.rect(cornerRadius: 16))
                    }
                    .modifier(MediaFileContextMenu(mediaFileInfo: mediaFileInfo, namespace: namespace))
                    .accessibilityLabel(accessibilityLabel)
                }
            }
            .scrollTargetLayout()
            .padding([.vertical, .trailing], 5)
            .padding(.leading, 0)
            .scenePadding(.bottom)
        }
        .scrollTargetBehavior(.viewAligned)
        .animation(.default, value: mediaFileInfos)
    }

    private func imageView(_ mediaFile: MediaFileInfo) -> some View {
        LazyImage(request: mediaFile.thumbRequest) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.clear.background(.thinMaterial)
            }
        }
        .frame(width: 150, height: 150)
    }
}

#Preview(traits: .previewEnvironment) {
    HorizontalFileListSection(
        label: "lorem ipsum", destination: .settings,
        mediaFileInfos: [
            .makeRandomUploaded(id: "1", .squareImage),
            .makeRandomUploaded(id: "2", .horizontalImage),
            .makeRandomUploaded(id: "3", .squareImage),
            .makeRandomUploaded(id: "4", .verticalImage),
        ])
}
