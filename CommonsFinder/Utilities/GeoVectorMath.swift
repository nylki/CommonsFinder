//
//  GeoVectorMath.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 25.07.25.
//

import CoreLocation
import Foundation
import MapKit
import simd

enum GeoVectorMath {

    /// Earth radius
    static let R = 6371_000.0  // meters

    func getCameraDirection(cameraLocation: CLLocationCoordinate2D, cameraBearing: CLLocationDegrees) -> SIMD2<Double> {
        let angleRad = cameraBearing.degreesToRadians
        let cameraDir = SIMD2<Double>(x: sin(angleRad), y: cos(angleRad))  // East-North
        return cameraDir
    }

    static func getBearing(a: CLLocationCoordinate2D, b: CLLocationCoordinate2D) -> CLLocationDegrees {
        let fLat = a.latitude.degreesToRadians
        let fLng = a.longitude.degreesToRadians
        let tLat = b.latitude.degreesToRadians
        let tLng = b.longitude.degreesToRadians

        let degree = (atan2(sin(tLng - fLng) * cos(tLat), cos(fLat) * sin(tLat) - sin(fLat) * cos(tLat) * cos(tLng - fLng))).radiansToDegrees

        if degree >= 0 {
            return degree
        } else {
            return 360 + degree
        }
    }


    static func calculateAngleBetween(cameraLocation: CLLocationCoordinate2D, cameraBearing: CLLocationDegrees, targetLocation: CLLocationCoordinate2D) -> CLLocationDegrees {
        let a = getBearing(a: cameraLocation, b: targetLocation).degreesToRadians
        let b = cameraBearing.degreesToRadians

        let angleDifference = atan2(sin(a - b), cos(a - b)).radiansToDegrees

        return abs(angleDifference)
    }

    static func getDestination(
        fromStart start: CLLocationCoordinate2D,
        bearing: CLLocationDegrees,
        distance d: Double
    ) -> CLLocationCoordinate2D {

        let bearingRad = bearing.degreesToRadians
        let startLonRad = start.longitude.degreesToRadians
        let startLatRad = start.latitude.degreesToRadians

        let relDist = d / R

        let destLatRad = asin(
            sin(startLatRad) * cos(relDist) + cos(startLatRad) * sin(relDist) * cos(bearingRad)
        )

        let destLonRad =
            startLonRad
            + atan2(
                sin(bearingRad) * sin(relDist) * cos(startLatRad),
                cos(relDist) - sin(startLatRad) * sin(destLatRad)
            )

        let destLat = destLatRad.radiansToDegrees
        let destLon =
            (destLonRad.radiansToDegrees + 540.0)
            .truncatingRemainder(dividingBy: 360.0) - 180

        return .init(
            latitude: destLat,
            longitude: destLon
        )
    }
}

extension FloatingPoint {
    fileprivate var degreesToRadians: Self { self * .pi / 180 }
    fileprivate var radiansToDegrees: Self { self * 180 / .pi }
}
