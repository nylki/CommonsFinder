//
//  ClusterModel.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 27.10.25.
//


import MapKit
import SwiftUI
import os.log

@Observable final class ClusterModel {
    var cluster: GeoCluster
    var mediaPaginationModel: PaginatableMediaFiles? = nil
    var resolvedCategories: [CategoryInfo] = []

    var humanReadableLocation: String?

    func fetchCenterLocation() {
        guard humanReadableLocation == nil else { return }
        Task<Void, Never> {
            do {
                humanReadableLocation = try await cluster.h3Center.generateHumanReadableString(
                    includeCountry: false,
                    includeCity: false
                )
            } catch {
                logger.error("Failed to resolve placemark \(error)")
            }
        }
    }


    /// The item that is scrolled to inside the sheet when tapping on a cluster circle
    var mapSheetFocusedClusterItem = ScrollPosition(idType: GeoReferencable.GeoRefID.self)

    init(cluster: GeoCluster) {
        self.cluster = cluster
        fetchCenterLocation()
    }
}
