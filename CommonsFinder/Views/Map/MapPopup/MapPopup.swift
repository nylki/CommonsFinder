//
//  MapPopup.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 04.03.25.
//

import Algorithms
import CommonsAPI
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


    let cluster: GeoCluster
    @Binding var scrollPosition: ScrollPosition
    @Binding var isPresented: Bool

    @State private var mediaPaginationModel: PaginatableMediaFiles? = nil
    @State private var resolvedCategories: [CategoryInfo] = []

    @Environment(\.appDatabase) private var appDatabase

    enum ItemType {
        case empty
        case wikiItem
        case mediaItem
    }

    @State private var selectedItemType: ItemType = .empty

    var body: some View {
        let selectedMediaIdx = cluster.mediaItems.firstIndex {
            $0.geoRefID == scrollPosition.viewID(type: String.self)
        }
        let selectedCategoryIdx = cluster.categoryItems.firstIndex {
            $0.geoRefID == scrollPosition.viewID(type: String.self)
        }
        
        let categoryCount = cluster.categoryItems.count
        let mediaCount = cluster.mediaItems.count

        VStack {
            HStack {
                if selectedItemType != .empty, categoryCount != 0, mediaCount != 0 {
                    Picker("", selection: $selectedItemType) {
                        let locationPickerLabel = if let selectedCategoryIdx {
                            Label("Locations (\(selectedCategoryIdx + 1)/\(categoryCount))", systemImage: "mappin")
                        } else {
                            Label("Locations (\(categoryCount))", systemImage: "mappin")
                        }
                        let mediaPickerLabel = if let selectedMediaIdx {
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
                    .onChange(of: selectedItemType) {
                        // TODO: set this implicitly in model or remember scrollPosition per type?
                        scrollPosition = .init()
                    }
                }

                Spacer()

                Button("Close", systemImage: "xmark") {
                    scrollPosition = .init()
                    isPresented = false
                }
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
                    .frame(height: 160)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .onAppear {
                        scrollPosition = .init(id: mediaFileInfo.id)
                    }
            } else {
                ScrollView(.horizontal) {
                    Group {
                        switch selectedItemType {
                        case .mediaItem:
                            mediaList
                                .containerShape(ViewConstants.pseudoSheetShape)
                                .frame(minWidth: 100)
                                .safeAreaPadding(.vertical, 10)
                                .safeAreaPadding(.horizontal, 120)
                                .frame(height: 160)
                                .scrollTargetLayout()
                        case .wikiItem:
                            wikiItemsList
                                .containerShape(ViewConstants.pseudoSheetShape)
                                .frame(minWidth: 100)
                                .safeAreaPadding(.vertical, 10)
                                .safeAreaPadding(.horizontal, 120)
                                .frame(height: 160)
                                .scrollTargetLayout()
                        case .empty:
                            EmptyView()
                        }
                    }

                }
                .scrollIndicators(.hidden)
                .clipped()
                // FIXME: scrollTargetBehavior glitches when scrolling distance is too forward+short
                //                .scrollTargetBehavior(.viewAligned)
                .scrollPosition($scrollPosition, anchor: .center)
            }
        }
        .sensoryFeedback(
            .selection, trigger: scrollPosition,
            condition: { oldValue, newValue in
                if oldValue.viewID == nil { return false }
                return newValue.viewID != nil
            }
        )
        .onChange(of: cluster, initial: true) {
            if selectedItemType == .empty {
                if categoryCount != 0 {
                    selectedItemType = .wikiItem
                } else if mediaCount != 0 {
                    selectedItemType = .mediaItem
                }
            }
        }

    }

    @ViewBuilder
    private var wikiItemsList: some View {
        LazyHStack {
            ForEach(resolvedCategories) { item in
                let isSelected = item.id == scrollPosition.viewID(type: String.self)
                MapPopupCategoryTeaser(item: item, isSelected: isSelected, namespace: namespace)
            }
        }
        .scrollTargetLayout()
        .onChange(of: resolvedCategories, initial: true) { oldValue, newValue in
            // set scroll position to first image if not yet
            if scrollPosition.viewID == nil,
                let firstItem = newValue.first
            {
                scrollPosition = .init(id: firstItem.id)
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

                    resolvedCategories = wikidataIDs.compactMap { wikidataID in
                        fetchedCategories[wikidataID]?.first ??
                        originalCategories[wikidataID]?.first
                        
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
                    let isSelected = mediaFileInfo.id == scrollPosition.viewID(type: String.self)
                    MapPopupMediaFileTeaser(namespace: namespace, mediaFileInfo: mediaFileInfo, isSelected: isSelected)
                        .onScrollVisibilityChange { visible in
                            guard visible else { return }
                            let threshold = min(mediaFileInfos.count - 1, max(0, mediaFileInfos.count - 5))
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
            if scrollPosition.viewID == nil,
                let firstMediaFile = newValue?.first
            {
                scrollPosition = .init(id: firstMediaFile.id)
            }
        }
        .task {
            guard mediaPaginationModel == nil else {
                return
            }

            do {
                mediaPaginationModel = try await .init(appDatabase: appDatabase, initialTitles: cluster.mediaItems.map(\.title))
                mediaPaginationModel?.paginate()
            } catch {
                logger.error("Failed to init file pagination \(error)")
            }
        }

    }
}

//#Preview(traits: .previewEnvironment) {
//    @Previewable @State var scrollPosition: ScrollPosition = .init()
//    MapPopup(scrollPosition: $scrollPosition, clusterIndex: 640371092026114823)
//}

#Preview("Interactive Sheet-Behaviour", traits: .previewEnvironment) {
    @Previewable @State var isShowing = false
    @Previewable @State var scrollPosition: ScrollPosition = .init()

    LinearGradient(colors: [.blue, .red, .black, .yellow, .green, .white, .gray], startPoint: .bottomLeading, endPoint: .topTrailing)
        .ignoresSafeArea()
        .pseudoSheet(isPresented: $isShowing) {
            MapPopup(
                cluster: try! .init(
                    h3Index: 640_371_092_026_114_823,
                    mediaItems: [],
                    categoryItems: [
                        .randomItem(id: "1"),
                        .randomItem(id: "2"),
                        .randomItem(id: "3"),
                        .randomItem(id: "4"),
                        .randomItem(id: "5"),
                        .randomItem(id: "6")
                    ]),
                scrollPosition: $scrollPosition,
                isPresented: $isShowing)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(500))
            isShowing = true
        }
}

struct PlatterContainer<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            //            .padding()
            .containerShape(shape)
        //            .background(shape.fill(.background))
    }
    var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 44) }
}
