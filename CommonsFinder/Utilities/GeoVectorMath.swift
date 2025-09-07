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

nonisolated enum GeoVectorMath {

    /// Earth radius
    static let earthRadius: CLLocationDistance = 6_371_008.8
    static let earthCircumference: CLLocationDistance = 40_075_016.6855785

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

        let degrees = (atan2(sin(tLng - fLng) * cos(tLat), cos(fLat) * sin(tLat) - sin(fLat) * cos(tLat) * cos(tLng - fLng))).radiansToDegrees

        return normalizeBearing(degrees: degrees)
    }

    static func normalizeBearing(degrees: CLLocationDegrees) -> CLLocationDegrees {
        if degrees >= 0 {
            return degrees
        } else {
            return 360 + degrees
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
        distance d: CLLocationDistance
    ) -> CLLocationCoordinate2D {

        let bearingRad = bearing.degreesToRadians
        let startLonRad = start.longitude.degreesToRadians
        let startLatRad = start.latitude.degreesToRadians

        let relDist = d / earthRadius

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

    // degrees from meters function
    // adapted from https://github.com/Outdooractive/gis-tools/blob/f6259f510548fe7879d3eea51566b8dc7ecda0af/Sources/GISTools/Algorithms/Conversions.swift#L177-L189
    // (MIT licensed)
    static func degrees(
        fromMeters meters: CLLocationDistance,
        atLatitude latitude: CLLocationDegrees
    ) -> (latitudeDegrees: CLLocationDegrees, longitudeDegrees: CLLocationDegrees) {
        // Length of one minute at this latitude
        let oneDegreeLatitudeDistance: CLLocationDistance = earthCircumference / 360.0  // ~111 km
        let oneDegreeLongitudeDistance: CLLocationDistance = cos(latitude * Double.pi / 180.0) * oneDegreeLatitudeDistance

        let longitudeDistance: Double = (meters / oneDegreeLongitudeDistance)
        let latitudeDistance: Double = (meters / oneDegreeLatitudeDistance)

        return (latitudeDistance, longitudeDistance)
    }

    static func meters(fromDegrees degrees: CLLocationDegrees) -> CLLocationDistance {
        degrees.degreesToRadians * earthRadius
    }
}

nonisolated extension FloatingPoint {
    fileprivate var degreesToRadians: Self { self * .pi / 180 }
    fileprivate var radiansToDegrees: Self { self * 180 / .pi }
}
