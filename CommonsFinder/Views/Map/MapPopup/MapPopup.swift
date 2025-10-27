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

    let model: ClusterModel
    let onClose: () -> Void


    @Environment(\.appDatabase) private var appDatabase

    enum ItemType {
        case empty
        case wikiItem
        case mediaItem
    }

    var resolvedCategories: [CategoryInfo] {
        model.mapSheetResolvedCategories
    }
    var mediaPaginationModel: PaginatableMediaFiles? {
        model.mapSheetMediaPaginationModel
    }

    var cluster: GeoCluster {
        model.cluster
    }

    var body: some View {
        @Bindable var mapModel = model
        let selectedMediaIdx = cluster.mediaItems.firstIndex {
            $0.geoRefID == mapModel.mapSheetFocusedClusterItem.viewID(type: String.self)
        }
        let selectedCategoryIdx = cluster.categoryItems.firstIndex {
            $0.geoRefID == mapModel.mapSheetFocusedClusterItem.viewID(type: String.self)
        }

        let categoryCount = cluster.categoryItems.count
        let mediaCount = cluster.mediaItems.count

        VStack {
            HStack {
                if mapModel.mapSheetSelectedItemType != .empty,
                    categoryCount != 0, mediaCount != 0
                {
                    Picker("", selection: $mapModel.mapSheetSelectedItemType) {
                        let locationPickerLabel =
                            if let selectedCategoryIdx {
                                Label("Locations (\(selectedCategoryIdx + 1)/\(categoryCount))", systemImage: "mappin")
                            } else {
                                Label("Locations (\(categoryCount))", systemImage: "mappin")
                            }
                        let mediaPickerLabel =
                            if let selectedMediaIdx {
                                Label("Images (\(selectedMediaIdx + 1)/\(mediaCount))", systemImage: "photo.stack")
                            } else {
                                Label("Images (\(mediaCount))", systemImage: "photo.stack")
                            }

                        locationPickerLabel
                            .tag(ItemType.wikiItem)

                        mediaPickerLabel
                            .tag(ItemType.mediaItem)
                    }
                    .pickerStyle(.segmented)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .padding(.horizontal)
                    .onChange(of: mapModel.mapSheetSelectedItemType) {
                        // TODO: set this implicitly in model or remember scrollPosition per type?
                        mapModel.mapSheetFocusedClusterItem = .init()
                    }
                }

                Spacer()

                Button("Close", systemImage: "xmark", action: onClose)
                    .glassButtonStyle()
                    .labelStyle(.iconOnly)
            }
            .padding([.top, .trailing])


            if mediaPaginationModel?.mediaFileInfos.count == 1,
                let mediaFileInfo = mediaPaginationModel?.mediaFileInfos.first
            {
                // Don't show a scroll view for a single item
                // TODO: this is temporary workaround and will change when single items are tappable directly on the map!
                MapPopupMediaFileTeaser(namespace: namespace, mediaFileInfo: mediaFileInfo, isSelected: true)
                    .padding(.vertical, 10)
                    .frame(height: 180)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .onAppear {
                        mapModel.mapSheetFocusedClusterItem = .init(id: mediaFileInfo.id)
                    }
            } else {


                switch mapModel.mapSheetSelectedItemType {
                case .mediaItem:
                    ScrollView(.horizontal) {
                        mediaList
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
                    // FIXME: scrollTargetBehavior glitches when scrolling distance is too forward+short
                    //                .scrollTargetBehavior(.viewAligned)
                    .scrollPosition($mapModel.mapSheetFocusedClusterItem, anchor: .center)

                case .wikiItem:
                    ScrollView(.horizontal) {
                        wikiItemsList
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
                    // FIXME: scrollTargetBehavior glitches when scrolling distance is too forward+short
                    //                .scrollTargetBehavior(.viewAligned)
                    .scrollPosition($mapModel.mapSheetFocusedClusterItem, anchor: .center)


                case .empty:
                    EmptyView()
                }
            }

        }
        .presentationBackgroundInteraction(.enabled)
        .sensoryFeedback(
            .selection, trigger: mapModel.mapSheetFocusedClusterItem,
            condition: { oldValue, newValue in
                if oldValue.viewID == nil { return false }
                return newValue.viewID != nil
            }
        )
        .onChange(of: cluster, initial: true) {
            if mapModel.mapSheetSelectedItemType == .empty {
                if categoryCount != 0 {
                    mapModel.mapSheetSelectedItemType = .wikiItem
                } else if mediaCount != 0 {
                    mapModel.mapSheetSelectedItemType = .mediaItem
                }
            }
        }

    }

    @ViewBuilder
    private var wikiItemsList: some View {
        LazyHStack {
            ForEach(resolvedCategories) { item in
                let isSelected = item.id == model.mapSheetFocusedClusterItem.viewID(type: String.self)
                MapPopupCategoryTeaser(item: item, isSelected: isSelected, namespace: namespace)
            }
        }
        // FIXME: asdasdas
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

                    model.mapSheetResolvedCategories = wikidataIDs.compactMap { wikidataID in
                        fetchedCategories[wikidataID]?.first ?? originalCategories[wikidataID]?.first

                    }
                }
            } catch {
                logger.error("Failed to observe Category changes in MapPopup \(error)")
            }

        }

    }

    @ViewBuilder
    private var mediaList: some View {
        LazyHStack {
            if let mediaPaginationModel {
                let mediaFileInfos = mediaPaginationModel.mediaFileInfos
                ForEach(mediaFileInfos) { mediaFileInfo in
                    let isSelected = mediaFileInfo.id == model.mapSheetFocusedClusterItem.viewID(type: String.self)
                    MapPopupMediaFileTeaser(namespace: namespace, mediaFileInfo: mediaFileInfo, isSelected: isSelected)
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
        .onChange(of: mediaPaginationModel?.mediaFileInfos, initial: true) { oldValue, newValue in
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
                model.mapSheetMediaPaginationModel = try await .init(appDatabase: appDatabase, initialTitles: cluster.mediaItems.map(\.title))
                mediaPaginationModel?.paginate()
            } catch {
                logger.error("Failed to init file pagination \(error)")
            }


        }

    }
}
