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

    func items(for index: H3Index, resolution: H3.Resolution) -> [GeoItem] {
        guard let itemIDs = h3IndexTree[resolution]?[index] else { return [] }
        return itemIDs.compactMap { items[$0] }
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

    func items(around coordinate: CLLocationCoordinate2D, radius: CLLocationDistance) -> [GeoItem] {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        // 1. get clusters inside the circle
        // 2. filter clusters to exclude outliers

        let resolutionsFromSmallestAreaToLargest = H3.Resolution.allCases.reversed()
        assert(resolutionsFromSmallestAreaToLargest.first == .fifteen)

        // we pick one step larger res to make sure we get all items, if if on the edges
        var resolution = resolutionsFromSmallestAreaToLargest.first { $0.approxCircleRadius > radius } ?? .zero
        resolution = .init(rawValue: resolution.rawValue - 1) ?? .zero
        do {
            let clusterIndex = try H3.latLngToCell(
                lat: coordinate.latitude.degreesToRadians,
                lng: coordinate.longitude.degreesToRadians,
                resolution: resolution
            )

            let itemsInCluster = items(for: clusterIndex, resolution: resolution)
            let filteredItems =
                itemsInCluster
                .filter { item in
                    guard let itemCoordinate = item.coordinate else {
                        assertionFailure()
                        return false
                    }
                    return location.distance(from: .init(latitude: itemCoordinate.latitude, longitude: itemCoordinate.longitude)) <= radius
                }
                .sorted { a, b in
                    guard let aCoord = a.coordinate, let bCoord = b.coordinate else { return false }
                    let aLoc = CLLocation(latitude: aCoord.latitude, longitude: aCoord.longitude)
                    let bLoc = CLLocation(latitude: bCoord.latitude, longitude: bCoord.longitude)
                    let aDist = aLoc.distance(from: location)
                    let bDist = bLoc.distance(from: location)
                    return aDist <= bDist
                }

            return filteredItems
        } catch {
            logger.error("Failed to find a matching cluster around (\(coordinate.latitude),\(coordinate.longitude)) with radius: \(radius): \(error)")
            return []
        }

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
