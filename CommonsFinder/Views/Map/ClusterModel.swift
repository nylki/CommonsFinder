//
//  ClusterModel.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 27.10.25.
//


import SwiftUI

@Observable final class ClusterModel {
    var cluster: GeoCluster
    var mediaPaginationModel: PaginatableMediaFiles? = nil
    var resolvedCategories: [CategoryInfo] = []
    var showingItemType: MapPopup.ItemType = .empty
    let possibleDetents: Set<PresentationDetent>
    var selectedDetent: PresentationDetent


    /// The item that is scrolled to inside the sheet when tapping on a cluster circle
    var mapSheetFocusedClusterItem = ScrollPosition(idType: GeoReferencable.GeoRefID.self)

    init(cluster: GeoCluster) {
        self.cluster = cluster
        let defaultDetent = PresentationDetent.height(275)
        possibleDetents = [defaultDetent, .large]
        selectedDetent = defaultDetent
    }
}
