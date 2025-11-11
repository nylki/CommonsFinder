//
//  CategoryClusterSheet.swift
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

struct CategoryClusterSheet: View {
    @Namespace private var namespace: Namespace.ID
    @Environment(\.locale) private var locale
    @Environment(Navigation.self) private var navigation
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let model: ClusterModel
    let mapAnimationNamespace: Namespace.ID
    let onClose: () -> Void


    @Environment(\.appDatabase) private var appDatabase

    var resolvedCategories: [CategoryInfo] {
        model.resolvedCategories
    }

    var cluster: GeoCluster { model.cluster }

    var selectedID: String? {
        model.mapSheetFocusedClusterItem.viewID(type: String.self)
    }

    private var currentItemTitle: Text? {
        return nil
    }

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            horizontalCategoryList
                .sensoryFeedback(
                    .selection, trigger: model.mapSheetFocusedClusterItem,
                    condition: { oldValue, newValue in
                        if oldValue.viewID == nil { return false }
                        return newValue.viewID != nil
                    }
                )
                .toolbar { toolbar }
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
        .presentationDetents([.height(250)])
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if let selectedCategoryIdx = cluster.categoryItems.firstIndex(where: { $0.geoRefID == selectedID }) {
                CounterView(current: selectedCategoryIdx + 1, max: model.cluster.categoryItems.count)
            }
        }

        ToolbarItem(placement: .title) {
            HStack(spacing: 5) {
                Image(systemName: "button.angledbottom.horizontal.left")
                VStack(alignment: .leading) {
                    Text("Orte im Gebiet")
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
            .safeAreaPadding(.horizontal, 120)
            .frame(height: 180)
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .clipped()
        .scrollPosition($model.mapSheetFocusedClusterItem, anchor: .center)
    }
}
