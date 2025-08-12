//
//  GeoClustering.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 24.02.25.
//

import CoreLocation
import H3kit
import MapKit
import os.log

protocol GeoReferencable: Hashable, Equatable {
    typealias GeoRefID = String
    var latitude: Double? { get }
    var longitude: Double? { get }
    var geoRefID: GeoRefID { get }
}

struct GeoClustering<Item: GeoReferencable> {
    typealias Index = UInt64
    var items: [GeoReferencable.GeoRefID: Item]
    var h3IndexTree: [H3.Resolution: [Index: Set<Item.GeoRefID>]]


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
    ) -> [Index: [Item]] {
        let latMax = topLeft.latitude
        let latMin = bottomRight.latitude
        let lonMin = topLeft.longitude
        let lonMax = bottomRight.longitude

        guard let indexTreeForPrecision = h3IndexTree[resolution] else {
            assertionFailure()

            return .init()
        }
        let matchingClusters: [(Index, [Item])] =
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
                let resolvedItems = ids.compactMap { items[$0] }
                return (index, resolvedItems)
            }

        return Dictionary(uniqueKeysWithValues: matchingClusters)
    }


    func items(forResolution resolution: H3.Resolution) -> [Index: [Item]] {
        guard let hashesForPrecision = h3IndexTree[resolution] else {
            return [:]
        }
        return hashesForPrecision.mapValues { ids in
            ids.compactMap { items[$0] }
        }
    }

    mutating func add(_ items: [Item]) {
        for item in items {
            _ = add(item)
        }
    }

    mutating func add(_ item: Item) -> Bool {
        guard let latRad = item.latitude?.degreesToRadians,
            let lngRad = item.longitude?.degreesToRadians
        else {
            return false
        }

        items[item.geoRefID] = item
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
        return true
    }

    func remove(_ item: Item) {

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
