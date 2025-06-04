//
//  MapPopup.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 04.03.25.
//

import CommonsAPI
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


    let clusterIndex: H3Index
    @Binding var scrollPosition: ScrollPosition
    /// wikidataItems are directly visualized
    let wikidataItems: [WikidataItem]
    /// rawMediaItems are not directly visualized, but passed to the pagination model to fetch the metadata including image url and caption
    let rawMediaItems: [GeosearchListItem]

    @State private var mediaPaginationModel: PaginatableMediaFiles? = nil

    private var selectedMediaFile: MediaFileInfo? {
        if let selectedID = scrollPosition.viewID(type: String.self) {
            mediaPaginationModel?.mediaFileInfos.first { $0.id == selectedID }
        } else {
            nil
        }
    }

    private var selectedWikiItem: WikidataItem? {
        if let selectedID = scrollPosition.viewID(type: String.self) {
            wikidataItems.first { $0.id == selectedID }
        } else {
            nil
        }
    }


    @Environment(\.appDatabase) private var appDatabase

    enum ItemType {
        case empty
        case wikiItem
        case mediaItem
    }

    @State private var selectedItemType: ItemType = .empty

    var body: some View {
        VStack {
            if selectedItemType != .empty, !wikidataItems.isEmpty, !rawMediaItems.isEmpty {
                Picker("", selection: $selectedItemType) {
                    Text("Locations").tag(ItemType.wikiItem)
                    Text("Images").tag(ItemType.mediaItem)

                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: selectedItemType) {
                    // TODO: set this implicitly in model or remember scrollPosition per type?
                    scrollPosition = .init()
                }
            }

            if mediaPaginationModel?.mediaFileInfos.count == 1,
                let mediaFileInfo = mediaPaginationModel?.mediaFileInfos.first
            {
                // Don't show a scroll view for a single item
                // TODO: this is temporary workaround and will change when single items are tappable directly on the map!
                MapPopupMediaItem(namespace: namespace, mediaFileInfo: mediaFileInfo, isSelected: true)
                    .padding(.vertical, 10)
                    .frame(height: 160)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .onAppear {
                        scrollPosition = .init(id: mediaFileInfo.id)
                    }
            } else {
                ScrollView(.horizontal) {
                    switch selectedItemType {
                    case .mediaItem:
                        mediaList
                            .frame(minWidth: 100)
                            .scrollTargetLayout()
                            .padding(.vertical, 10)
                            .padding(.leading, 120)
                            .padding(.trailing, 120)
                            .frame(height: 160)
                    case .wikiItem:
                        wikiItemsList
                            .frame(minWidth: 100)
                            .scrollTargetLayout()
                            .padding(.vertical, 10)
                            .padding(.leading, 120)
                            .padding(.trailing, 120)
                            .frame(height: 160)
                    case .empty:
                        EmptyView()
                    }
                }
                .onAppear {
                    if selectedItemType == .empty {
                        if !wikidataItems.isEmpty {
                            selectedItemType = .wikiItem
                        } else if !rawMediaItems.isEmpty {
                            selectedItemType = .mediaItem
                        }
                    }

                }
                .scrollIndicators(.hidden)
                .clipped()
                .scrollPosition($scrollPosition, anchor: .center)
            }
        }
        .sensoryFeedback(
            .selection, trigger: scrollPosition,
            condition: { oldValue, newValue in
                newValue.viewID != nil
            }
        )
        .safeAreaInset(edge: .top) {
            Capsule()
                .frame(width: 40, height: 5)
                .opacity(0.4)
                .padding(.vertical, 10)
        }
        .background(Material.regular)
        .clipShape(.rect(cornerRadius: 20))
        .padding()  // Outer padding to show the view behind
        .geometryGroup()
        .compositingGroup()
        .shadow(radius: 30)
    }

    @ViewBuilder
    private var wikiItemsList: some View {
        LazyHStack {
            ForEach(wikidataItems) { item in
                let isSelected = item.id == scrollPosition.viewID(type: String.self)
                MapPopupWikiItem(item: item, isSelected: isSelected, namespace: namespace)
            }
        }
        .onChange(of: wikidataItems, initial: true) { oldValue, newValue in
            // set scroll position to first image if not yet
            if scrollPosition.viewID == nil,
                let firstItem = newValue.first
            {
                scrollPosition = .init(id: firstItem.id)
            }
        }

    }

    @ViewBuilder
    private var mediaList: some View {
        LazyHStack {
            if let mediaPaginationModel {
                let mediaFileInfos = mediaPaginationModel.mediaFileInfos
                if mediaFileInfos.isEmpty {
                    ProgressView()
                        .frame(width: 100).progressViewStyle(.circular)
                }
                ForEach(mediaFileInfos) { mediaFileInfo in
                    let isSelected = mediaFileInfo.id == scrollPosition.viewID(type: String.self)
                    MapPopupMediaItem(namespace: namespace, mediaFileInfo: mediaFileInfo, isSelected: isSelected)
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
                mediaPaginationModel = try await .init(appDatabase: appDatabase, initialTitles: rawMediaItems.map(\.title))
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

    Color.clear
        .pseudoSheet(isPresented: $isShowing) {
            MapPopup(
                clusterIndex: 640_371_092_026_114_823, scrollPosition: $scrollPosition,
                wikidataItems: [.randomItem(id: "1"), .randomItem(id: "2"), .randomItem(id: "3"), .randomItem(id: "4"), .randomItem(id: "5"), .randomItem(id: "5")],
                rawMediaItems: [
                    //                .makeRandomUploaded(id: "1", .squareImage),
                    //                .makeRandomUploaded(id: "2", .horizontalImage),
                    //                .makeRandomUploaded(id: "3", .verticalImage)
                ])
            //            MapPopup(scrollPosition: $scrollPosition, clusterIndex: 640371092026114823)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(500))
            isShowing = true
        }
}
