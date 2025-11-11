//
//  MKCoordinateRegion+extras.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 07.11.25.
//

import MapKit

extension MKCoordinateRegion {
    var metersInLatitude: Double {
        span.latitudeDelta * 111_320
    }

    /// area in m^2
    var area: Double {
        metersInLatitude * metersInLongitude
    }

    var metersInLongitude: Double {
        let metersPerDegreeLongitude = cos(center.latitude * .pi / 180.0) * 111_320
        return span.longitudeDelta * metersPerDegreeLongitude
    }

    var diagonalMeters: Double {
        sqrt(pow(metersInLatitude, 2) + pow(metersInLongitude, 2))
    }

    var boundingBox: (topLeft: CLLocationCoordinate2D, bottomRight: CLLocationCoordinate2D) {
        let halfLatDelata = span.latitudeDelta / 2
        let halfLonDelta = span.longitudeDelta / 2

        let topLeftCoordinateLat = center.latitude + halfLatDelata
        let topLeftCoordinateLon = center.longitude - halfLonDelta

        let bottomRightCoordinateLat = center.latitude - halfLatDelata
        let bottomRightCoordinateLon = center.longitude + halfLonDelta

        let topLeftCoordinate = CLLocationCoordinate2D(
            latitude: topLeftCoordinateLat,
            longitude: topLeftCoordinateLon
        )

        let bottomRightCoordinate = CLLocationCoordinate2D(
            latitude: bottomRightCoordinateLat,
            longitude: bottomRightCoordinateLon
        )

        return (topLeftCoordinate, bottomRightCoordinate)

    }
}
