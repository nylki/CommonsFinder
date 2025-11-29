//
//  HorizontalMediaMapList.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 18.11.25.
//

import SwiftUI

struct HorizontalMediaMapList: View {
    @Binding var focusedItem: ScrollPosition
    let paginationModel: PaginatableMediaFiles
    let mapAnimationNamespace: Namespace.ID

    @Environment(Navigation.self) private var navigation
    @Environment(MediaFileReactiveCache.self) private var mediaFileCache

    var body: some View {
        @Bindable var paginationModel = paginationModel
        let mediaFileInfos = paginationModel.mediaFileInfos
        let isSingleImage = mediaFileInfos.count == 1
        ScrollView(.horizontal) {
            LazyHStack {
                ForEach(mediaFileInfos) { mediaFileInfo in
                    let isSelected = mediaFileInfo.id == focusedItem.viewID(type: String.self)
                    MapPopupMediaFileTeaser(
                        namespace: mapAnimationNamespace,
                        mediaFileInfo: mediaFileInfo,
                        size: isSingleImage ? .wide : .regular,
                        isSelected: isSelected
                    ) {
                        navigation.viewFile(mediaFile: mediaFileInfo, namespace: mapAnimationNamespace)
                    }
                    .onScrollVisibilityChange { visible in
                        // FIXME: debounce
                        guard visible, paginationModel.status != .idle(reachedEnd: true), paginationModel.status != .isPaginating else { return }
                        let threshold = min(mediaFileInfos.count - 1, max(0, mediaFileInfos.count - 3))
                        guard threshold > 0 else { return }
                        let thresholdItem = mediaFileInfos[threshold]

                        if mediaFileInfo == thresholdItem {
                            paginationModel.paginate()
                        }
                    }
                }

                if paginationModel.status == .isPaginating {
                    ProgressView()
                        .frame(width: 100).progressViewStyle(.circular)
                }

            }
            .containerShape(ViewConstants.mapSheetContainerShape)
            .frame(minWidth: 100)
            .safeAreaPadding(.horizontal, 120)
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        //            .clipped()
        .scrollPosition($focusedItem, anchor: .center)
        .sensoryFeedback(.selection, trigger: focusedItem) { oldValue, newValue in
            if oldValue.viewID == nil { return false }
            return newValue.viewID != nil
        }
        .onChange(of: paginationModel.mediaFileInfos, initial: true) { oldValue, newValue in
            for mediaFileInfo in newValue {
                mediaFileCache.cache(mediaFileInfo)
            }

            // set scroll position to first image if not yet
            if focusedItem.viewID == nil, let firstMediaFile = newValue.first {
                focusedItem = .init(id: firstMediaFile.id)
            }
        }
    }
}
