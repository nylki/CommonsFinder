//
//  GeoClusterTree.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 24.02.25.
//

import CoreLocation
import H3kit
import MapKit
import os.log

nonisolated final class GeoClusterTree {
    var items: [GeoReferencable.GeoRefID: GeoItem]
    var h3IndexTree: [H3.Resolution: [H3Index: Set<GeoReferencable.GeoRefID>]]

    /// this gets cleared whenever `items` is modified
    private var currentClusterCache: [H3Index: GeoCluster] = [:]

    init() {
        self.items = [:]
        h3IndexTree = [:]

        for resolution in H3.Resolution.allCases {
            h3IndexTree[resolution] = [:]
        }
    }

    func clusters(
        topLeft: CLLocationCoordinate2D,
        bottomRight: CLLocationCoordinate2D,
        resolution: H3.Resolution
    ) -> [H3Index: GeoCluster] {
        let latMax = topLeft.latitude
        let latMin = bottomRight.latitude
        let lonMin = topLeft.longitude
        let lonMax = bottomRight.longitude

        guard let indexTreeForPrecision = h3IndexTree[resolution] else {
            assertionFailure()
            return .init()
        }

        let matchingClusters: [(H3Index, GeoCluster)] =
            indexTreeForPrecision.filter { index, itemIds in

                // The decoded hash coordinates could be memoized
                guard let (latRad, lonRad) = try? H3.cellToLatLng(h3Index: index) else {
                    return false
                }
                let lat = latRad.radiansToDegrees
                let lon = lonRad.radiansToDegrees

                let isInBoundingBox = lat >= latMin && lat < latMax && lon >= lonMin && lon < lonMax
                return isInBoundingBox
            }
            .compactMap { (index, ids) in

                if let cachedCluster = currentClusterCache[index] {
                    //                    logger.debug("M: use cached GeoCluster")
                    return (index, cachedCluster)
                }

                let resolvedItems = ids.compactMap { items[$0] }
                let resolvedMediaItems = resolvedItems.compactMap { $0.media }
                let resolvedCategoryItems = resolvedItems.compactMap { $0.category }

                let cluster = try? GeoCluster(h3Index: index, mediaItems: resolvedMediaItems, categoryItems: resolvedCategoryItems)
                self.currentClusterCache[index] = cluster
                //                logger.debug("M: create new GeoCluster")

                if let cluster {
                    return (index, cluster)
                } else {
                    return nil
                }
            }

        return Dictionary(uniqueKeysWithValues: matchingClusters)
    }

    func add(_ items: [GeoItem]) {
        currentClusterCache.removeAll()
        for item in items {
            guard let longitude = item.longitude,
                let latitude = item.latitude
            else { continue }

            self.items[item.geoRefID] = item

            let latRad = latitude.degreesToRadians
            let lngRad = longitude.degreesToRadians

            for resolution in H3.Resolution.allCases {
                do {
                    let index = try H3.latLngToCell(lat: latRad, lng: lngRad, resolution: resolution)

                    if h3IndexTree[resolution]?[index] == nil {
                        h3IndexTree[resolution]?[index] = .init()
                    }
                    h3IndexTree[resolution]?[index]?.insert(item.geoRefID)
                } catch {
                    logger.error("Failed to add coordinate \(error)")
                }
            }
        }
    }
}


extension CLLocationCoordinate2D {
    func isLocationInBoundingBox(
        topLeft: CLLocationCoordinate2D, bottomRight: CLLocationCoordinate2D
    ) -> Bool {
        return latitude <= topLeft.latitude && latitude >= bottomRight.latitude && longitude >= topLeft.longitude && longitude <= bottomRight.longitude
    }
}


extension MKCoordinateRegion: @retroactive Equatable, @retroactive Hashable {
    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        lhs.area == rhs.area && lhs.center == rhs.center && lhs.span.latitudeDelta == rhs.span.latitudeDelta && lhs.span.longitudeDelta == rhs.span.longitudeDelta
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(area)
        hasher.combine(center)
        hasher.combine(span.latitudeDelta)
        hasher.combine(span.longitudeDelta)
    }


}
