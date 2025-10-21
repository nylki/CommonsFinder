//
//  GeoCluster.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 20.10.25.
//

import CommonsAPI
import CoreLocation
import Foundation
import H3kit
import MapKit
import os.log

nonisolated
    struct GeoCluster: Hashable, Equatable, Identifiable
{
    let h3Index: H3Index
    var mediaItems: [GeoSearchFileItem]
    var categoryItems: [Category]
    let allCoordinates: [CLLocationCoordinate2D]
    let h3Center: CLLocationCoordinate2D
    let meanCenter: CLLocationCoordinate2D
    let hullPolygon: MKPolygon

    var id: H3Index { h3Index }

    init(h3Index: H3Index, mediaItems: [GeoSearchFileItem], categoryItems: [Category]) throws {
        self.h3Index = h3Index
        self.mediaItems = mediaItems
        self.categoryItems = categoryItems

        let (latRad, lonRad) = try H3.cellToLatLng(h3Index: h3Index)
        let lat = latRad.radiansToDegrees
        let lon = lonRad.radiansToDegrees
        allCoordinates = mediaItems.compactMap(\.coordinate) + categoryItems.compactMap(\.coordinate)
        h3Center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        meanCenter = GeoVectorMath.calculateMeanCenter(coordinates: allCoordinates)
        let concavity: Double

        if allCoordinates.count > 50, let res = H3.getResolution(index: h3Index) {
            let degDiameter = GeoVectorMath.degrees(fromMeters: res.approxCircleRadius, atLatitude: lat)
            concavity = ((degDiameter.latitudeDegrees + degDiameter.longitudeDegrees) / 2)
        } else {
            concavity = 20
        }

        let hullCoordinates = ConcaveHull.calculateHull(coordinates: allCoordinates, concavity: concavity)
        hullPolygon = MKPolygon(coordinates: hullCoordinates, count: hullCoordinates.count)
    }
}
