//
//  MediaClusterSheet.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 07.11.25.
//

import Algorithms
import GRDB
import H3kit
import NukeUI
import SwiftUI
import os.log

struct MediaClusterSheet: View {
    @Namespace private var namespace: Namespace.ID
    @Environment(\.locale) private var locale
    @Environment(Navigation.self) private var navigation
    @Environment(MediaFileReactiveCache.self) private var mediaFileCache
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let model: ClusterModel
    let mapAnimationNamespace: Namespace.ID
    let onClose: () -> Void

    @Environment(\.appDatabase) private var appDatabase

    @State private var selectedDetent: PresentationDetent = .height(270)

    var mediaPaginationModel: PaginatableMediaFiles? {
        model.mediaPaginationModel
    }

    var cluster: GeoCluster { model.cluster }

    var selectedID: String? {
        model.mapSheetFocusedClusterItem.viewID(type: String.self)
    }

    private var currentItemTitle: Text? {
        if let selectedImage = model.mediaPaginationModel?.mediaFileInfos.first(where: { $0.id == selectedID }) {
            return Text(selectedImage.mediaFile.bestShortTitle)
        } else {
            return nil
        }
    }

    private let topSafeArea = 70.0

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {

                    horizontalMediaList

                    if let currentItemTitle {
                        currentItemTitle
                            .padding()
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0)
                }
                //NOTE: the regular top safe area is ignore (below), because it appears to be too large
                // instead a better fitted one is used here. May need to adjust or re-test in future versions or different
                // detents and configs.
                .padding(.top, topSafeArea)
            }

            .ignoresSafeArea(.container, edges: .top)
            .sensoryFeedback(
                .selection, trigger: model.mapSheetFocusedClusterItem,
                condition: { oldValue, newValue in
                    if oldValue.viewID == nil { return false }
                    return newValue.viewID != nil
                }
            )
            .toolbar { toolbar }
            .onChange(of: mediaPaginationModel?.mediaFileInfos, initial: true) { oldValue, newValue in
                if let newValue {
                    for mediaFileInfo in newValue {
                        mediaFileCache.cache(mediaFileInfo)
                    }
                }
                // set scroll position to first image if not yet
                if model.mapSheetFocusedClusterItem.viewID == nil,
                    let firstMediaFile = newValue?.first
                {
                    model.mapSheetFocusedClusterItem = .init(id: firstMediaFile.id)
                }
            }
            .task {
                guard model.mediaPaginationModel == nil else { return }
                do {
                    model.mediaPaginationModel = try await .init(appDatabase: appDatabase, initialTitles: cluster.mediaItems.map(\.title))
                    mediaPaginationModel?.paginate()
                } catch {
                    logger.error("Failed to init file pagination \(error)")
                }
            }
        }
        .presentationDetents([.height(270), .medium])
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if let selectedMediaIdx = cluster.mediaItems.firstIndex(where: { $0.geoRefID == selectedID }) {
                CounterView(current: selectedMediaIdx + 1, max: cluster.mediaItems.count)
            }
        }

        ToolbarItem(placement: .title) {
            HStack(spacing: 5) {
                Image(systemName: "button.angledbottom.horizontal.left")
                VStack(alignment: .leading) {
                    Text("Bilder im Gebiet")
                        .bold()
                    // TODO: use wikidata item with area
                    Text(model.humanReadableLocation ?? "             ")
                        .lineLimit(1)
                        .font(.caption)
                }
                Spacer(minLength: 0)
            }
            .allowsTightening(true)
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button("Close", systemImage: "xmark", action: onClose)
                .labelStyle(.iconOnly)
        }
    }


    @ViewBuilder
    private var horizontalMediaList: some View {
        @Bindable var model = model

        ScrollView(.horizontal) {
            LazyHStack {
                if let mediaPaginationModel {
                    let mediaFileInfos = mediaPaginationModel.mediaFileInfos
                    ForEach(mediaFileInfos) { mediaFileInfo in
                        let isSelected = mediaFileInfo.id == model.mapSheetFocusedClusterItem.viewID(type: String.self)
                        MapPopupMediaFileTeaser(namespace: mapAnimationNamespace, mediaFileInfo: mediaFileInfo, isSelected: isSelected) {
                            navigation.viewFile(mediaFile: mediaFileInfo, namespace: mapAnimationNamespace)
                        }
                        .onScrollVisibilityChange { visible in
                            // FIXME: debounce
                            guard visible, mediaPaginationModel.status != .idle(reachedEnd: true), mediaPaginationModel.status != .isPaginating else { return }
                            let threshold = min(mediaFileInfos.count - 1, max(0, mediaFileInfos.count - 1))
                            guard threshold > 0 else { return }
                            let thresholdItem = mediaFileInfos[threshold]

                            if mediaFileInfo == thresholdItem {
                                mediaPaginationModel.paginate()
                            }
                        }
                    }

                    if mediaPaginationModel.status == .isPaginating {
                        ProgressView()
                            .frame(width: 100).progressViewStyle(.circular)
                    }
                } else {
                    ProgressView()
                        .frame(width: 100).progressViewStyle(.circular)
                }
            }
            .frame(minWidth: 100)
            .safeAreaPadding(.horizontal, 120)
            .scrollTargetLayout()

        }
        .scrollIndicators(.hidden)
        //            .clipped()
        .scrollPosition($model.mapSheetFocusedClusterItem, anchor: .center)
    }
}
