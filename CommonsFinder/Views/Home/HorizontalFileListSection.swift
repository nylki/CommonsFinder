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
                    let accessibilityLabel = Text(mediaFileInfo.mediaFile.bestShortTitle)

                    let navItem = NavigationStackItem.viewFile(
                        mediaFileInfo, namespace: namespace
                    )
                    NavigationLink(value: navItem) {
                        MediaFileThumbImage(mediaFileInfo)
                            .frame(width: 150, height: 150)
                            .clipped()
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
