//
//  GeoCluster.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 20.10.25.
//

import CommonsAPI
import CoreLocation
import Foundation
import GEOSwift
import GEOSwiftMapKit
import H3kit
import MapKit
import os.log

nonisolated struct BasicGeoMediaFile: Equatable, Hashable, Identifiable {
    let coordinate: CLLocationCoordinate2D
    /// pageID
    let id: String
    let title: String

    /// non-prefixed filename (without FILE:)
    var fileName: String? {
        if let nonPrefixed = title.split(separator: "File:").first {
            String(nonPrefixed)
        } else {
            nil
        }
    }

    init(apiItem: GeoSearchFileItem) {
        coordinate = .init(latitude: apiItem.lat, longitude: apiItem.lon)
        title = apiItem.title
        id = apiItem.id
    }

    init(id: String, coordinate: CLLocationCoordinate2D, title: String) {
        self.id = id
        self.coordinate = coordinate
        self.title = title

    }
}

nonisolated
    struct GeoCluster: Hashable, Equatable, Identifiable
{
    let h3Index: H3Index
    var mediaItems: [BasicGeoMediaFile]
    var categoryItems: [Category]
    let allCoordinates: [CLLocationCoordinate2D]
    let h3Center: CLLocationCoordinate2D
    let meanCenter: CLLocationCoordinate2D
    let meanCenterMedia: CLLocationCoordinate2D
    let meanCenterCategories: CLLocationCoordinate2D

    let mediaGeometry: Geometry?
    let categoryGeometry: Geometry?
    let mediaHull: MKPolygon
    let categoryHull: MKPolygon

    var id: H3Index { h3Index }

    init(h3Index: H3Index, mediaItems: [BasicGeoMediaFile], categoryItems: [Category]) throws {
        self.h3Index = h3Index
        self.mediaItems = mediaItems
        self.categoryItems = categoryItems

        let (latRad, lonRad) = try H3.cellToLatLng(h3Index: h3Index)
        let lat = latRad.radiansToDegrees
        let lon = lonRad.radiansToDegrees
        let mediaCoordinates = mediaItems.compactMap(\.coordinate)
        let categoryCoordinates = categoryItems.compactMap(\.coordinate)
        allCoordinates = mediaCoordinates + categoryCoordinates
        h3Center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        meanCenter = GeoVectorMath.calculateMeanCenter(coordinates: allCoordinates)
        meanCenterMedia = GeoVectorMath.calculateMeanCenter(coordinates: mediaCoordinates)
        meanCenterCategories = GeoVectorMath.calculateMeanCenter(coordinates: categoryCoordinates)

        let mediaPoints: MultiPoint = .init(points: mediaCoordinates.map(Point.init))
        let categoryPoints: MultiPoint = .init(points: categoryCoordinates.map(Point.init))

        do {
            mediaGeometry = try mediaPoints.convexHull()

            mediaHull =
                switch mediaGeometry {
                case .point(_):
                    .init()
                case .multiPoint(_):
                    .init()
                case .lineString(_):
                    .init()
                case .multiLineString(_):
                    .init()
                case .polygon(let polygon):
                    MKPolygon.init(polygon: polygon)
                case .multiPolygon(_):
                    .init()
                case .geometryCollection(_):
                    .init()
                case .none:
                    .init()
                }
        } catch {
            logger.warning("Failed to created cluster \(error)")
            mediaHull = .init()
            mediaGeometry = nil
        }

        do {
            categoryGeometry = try categoryPoints.convexHull()
            categoryHull =
                switch categoryGeometry {
                case .point(_):
                    .init()
                case .multiPoint(_):
                    .init()
                case .lineString(_):
                    .init()
                case .multiLineString(_):
                    .init()
                case .polygon(let polygon):
                    MKPolygon.init(polygon: polygon)
                case .multiPolygon(_):
                    .init()
                case .geometryCollection(_):
                    .init()
                case .none:
                    .init()
                }
        } catch {
            logger.warning("Failed to created cluster \(error)")
            categoryHull = .init()
            categoryGeometry = nil
        }
    }
}

extension GeoCluster {
    func cameraRegion(paddingFactor: Double = 0.5, withSheetOffset: Bool = true) -> MKCoordinateRegion? {
        guard let res = h3Index.resolution else { return nil }
        let delta = GeoVectorMath.degrees(fromMeters: res.approxCircleRadius * 2, atLatitude: h3Center.latitude)
        let dLat = delta.latitudeDegrees + delta.latitudeDegrees * paddingFactor
        let dLon = delta.longitudeDegrees + delta.longitudeDegrees * paddingFactor

        var center = h3Center

        if withSheetOffset {
            // We offset the center a bit to the north, so that the map sheet doesn't overlap parts of the cluster (approximated)
            center.latitude = center.latitude - (delta.latitudeDegrees * 0.2)
        }
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: dLat,
                longitudeDelta: dLon
            )
        )
    }
}
