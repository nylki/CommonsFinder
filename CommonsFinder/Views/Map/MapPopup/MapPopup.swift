//
//  MapPopup.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 04.03.25.
//

import Algorithms
import CommonsAPI
import FrameUp
import GRDB
import H3kit
import NukeUI
import SwiftUI
import os.log

private enum ClusterTab: Hashable, CaseIterable {
    case wikidataItems
    case files
}

extension ClusterTab {
    var label: LocalizedStringKey {
        switch self {
        case .wikidataItems:
            "Wikidata Items"
        case .files:
            "Media"
        }
    }
}

struct MapPopup: View {
    @Namespace private var namespace: Namespace.ID
    @Environment(\.locale) private var locale
    @Environment(Navigation.self) private var navigation
    @Environment(MediaFileReactiveCache.self) private var mediaFileCache
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let model: ClusterModel
    let pickedItemType: MapItemType
    let mapAnimationNamespace: Namespace.ID
    let onClose: () -> Void


    @Environment(\.appDatabase) private var appDatabase

    var resolvedCategories: [CategoryInfo] {
        model.resolvedCategories
    }
    var mediaPaginationModel: PaginatableMediaFiles? {
        model.mediaPaginationModel
    }

    var cluster: GeoCluster {
        model.cluster
    }

    var body: some View {
        @Bindable var model = model


        let categoryCount = cluster.categoryItems.count
        let mediaCount = cluster.mediaItems.count

        NavigationStack {
            VStack {
                let selectedID = model.mapSheetFocusedClusterItem.viewID(type: String.self)

                switch pickedItemType {
                case .mediaItem:
                    mediaList

                case .wikiItem:
                    categoryList
                }


            }
            .sensoryFeedback(
                .selection, trigger: model.mapSheetFocusedClusterItem,
                condition: { oldValue, newValue in
                    guard model.selectedDetent != .large else { return false }
                    if oldValue.viewID == nil { return false }
                    return newValue.viewID != nil
                }
            )
            .toolbar {
                let selectedID = model.mapSheetFocusedClusterItem.viewID(type: String.self)

                ToolbarItem(placement: .topBarLeading) {
                    ZStack {
                        switch pickedItemType {
                        case .mediaItem:
                            let selectedMediaIdx = cluster.mediaItems.firstIndex { $0.geoRefID == selectedID }
                            if let selectedMediaIdx {
                                let currentNr = selectedMediaIdx + 1
                                let text = "\(currentNr) / \(model.cluster.mediaItems.count)"
                                Text(text)
                                    .frame(width: Double(text.count) * 10.0)
                                    .contentTransition(.numericText(value: Double(currentNr)))
                            }
                        case .wikiItem:
                            let selectedCategoryIdx = cluster.categoryItems.firstIndex { $0.geoRefID == selectedID }
                            if let selectedCategoryIdx {
                                let currentNr = selectedCategoryIdx + 1
                                let text = "\(selectedCategoryIdx + 1) / \(model.cluster.categoryItems.count)"
                                Text(text)
                                    .frame(width: Double(text.count) * 10.0)
                                    .contentTransition(.numericText(value: Double(currentNr)))
                            }
                        }
                    }

                    .animation(.default, value: selectedID)
                }

                if let selectedID {
                    ToolbarItem(placement: .principal) {
                        VStack(alignment: .leading) {
                            if pickedItemType == .mediaItem,
                                let selectedImage = model.mediaPaginationModel?.mediaFileInfos.first(where: { $0.id == selectedID })
                            {
                                Text(selectedImage.mediaFile.displayName)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                    .transition(.slide)
                                    .font(.footnote)
                            }


                            //                        if let humanReadableLocation = model.humanReadableLocation {
                            //                            Text(humanReadableLocation)
                            //                                .font(.footnote)
                            //                                .foregroundStyle(.secondary)
                            //                        }
                        }
                        .frame(height: 100)

                    }


                }


                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark", action: onClose)
                        .labelStyle(.iconOnly)
                }
            }
        }

    }

    @ViewBuilder
    private var categoryList: some View {
        ZStack {
            horizontalCategoryList
        }
        .onChange(of: resolvedCategories, initial: true) {
            // set scroll position to first image if not yet
            if model.mapSheetFocusedClusterItem.viewID == nil,
                let firstItem = resolvedCategories.first
            {
                model.mapSheetFocusedClusterItem = .init(id: firstItem.id)
            }
        }
        .task(id: cluster.categoryItems) {
            do {
                let wikidataIDs = cluster.categoryItems
                    .compactMap(\.wikidataId)

                let observation = ValueObservation.tracking { db in
                    try CategoryInfo
                        .fetchAll(db, wikidataIDs: wikidataIDs, resolveRedirections: true)
                }
                for try await result in observation.values(in: appDatabase.reader) {
                    let fetchedCategories =
                        result
                        .grouped(by: \.base.wikidataId)

                    let originalCategories = cluster.categoryItems
                        .map { CategoryInfo($0, itemInteraction: nil) }
                        .grouped(by: \.base.wikidataId)

                    model.resolvedCategories = wikidataIDs.compactMap { wikidataID in
                        fetchedCategories[wikidataID]?.first ?? originalCategories[wikidataID]?.first

                    }
                }
            } catch {
                logger.error("Failed to observe Category changes in MapPopup \(error)")
            }

        }
    }

    @ViewBuilder
    private var horizontalCategoryList: some View {
        @Bindable var model = model

        ScrollView(.horizontal) {
            LazyHStack {
                ForEach(resolvedCategories) { item in
                    let isSelected = item.id == model.mapSheetFocusedClusterItem.viewID(type: String.self)
                    MapPopupCategoryTeaser(item: item, isSelected: isSelected, namespace: mapAnimationNamespace)
                }
            }

            .containerShape(ViewConstants.pseudoSheetShape)
            .frame(minWidth: 100)
            .safeAreaPadding(.vertical, 10)
            .safeAreaPadding(.horizontal, 120)
            .frame(height: 180)
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .clipped()
        .padding(.vertical, 5)
        .scrollPosition($model.mapSheetFocusedClusterItem, anchor: .center)
    }

    @ViewBuilder private var mediaList: some View {
        @Bindable var model = model
        ZStack {
            horizontalMediaList
        }
        //        .animation(.default, value: model.selectedDetent)
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

            guard mediaPaginationModel == nil else {
                //                try? await Task.sleep(for: .milliseconds(200))
                //                model.mapSheetFocusedClusterItem.scrollTo(id: model.mapSheetFocusedClusterItem.viewID(type: String.self), anchor: .center)
                return
            }

            do {
                model.mediaPaginationModel = try await .init(appDatabase: appDatabase, initialTitles: cluster.mediaItems.map(\.title))
                mediaPaginationModel?.paginate()
            } catch {
                logger.error("Failed to init file pagination \(error)")
            }


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
                            model.mapSheetFocusedClusterItem = .init(id: mediaFileInfo.id)
                            Task {
                                try? await Task.sleep(for: .milliseconds(25))
                                navigation.viewFile(mediaFile: mediaFileInfo, namespace: mapAnimationNamespace)
                            }
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
            .containerShape(ViewConstants.pseudoSheetShape)
            .frame(minWidth: 100)
            .safeAreaPadding(.vertical, 10)
            .safeAreaPadding(.horizontal, 120)
            .frame(height: 180)
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .clipped()
        .padding(.vertical, 5)
        .scrollPosition($model.mapSheetFocusedClusterItem, anchor: .center)
    }
}
