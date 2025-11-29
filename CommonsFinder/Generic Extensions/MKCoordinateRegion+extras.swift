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

    func paddedBoundingBox(paddingFactor: Double = 0.15) -> (topLeft: CLLocationCoordinate2D, bottomRight: CLLocationCoordinate2D) {
        let halfLatDelta = span.latitudeDelta / 2
        let halfLonDelta = span.longitudeDelta / 2

        let latPadding = span.latitudeDelta * paddingFactor
        let lonPadding = span.longitudeDelta * paddingFactor

        let topLeftCoordinateLat = center.latitude + (halfLatDelta + latPadding)
        let topLeftCoordinateLon = center.longitude - (halfLonDelta + lonPadding)

        let bottomRightCoordinateLat = center.latitude - (halfLatDelta + latPadding)
        let bottomRightCoordinateLon = center.longitude + (halfLonDelta + lonPadding)

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

    /// padding values are factors of the region lan/lat delta (eg. top:0.25 would add a padding on the top edge of 25% of the vertical length
    /// negative paddings subtract the padding, in effect shrinking the area of the bounding box
    func paddedBoundingBox(top: Double, bottom: Double, left: Double, right: Double) -> (topLeft: CLLocationCoordinate2D, bottomRight: CLLocationCoordinate2D) {
        let halfLatDelta = span.latitudeDelta / 2
        let halfLonDelta = span.longitudeDelta / 2

        let latPaddingTop = span.latitudeDelta * top
        let latPaddingBottom = span.latitudeDelta * bottom
        let lonPaddingLeft = span.longitudeDelta * left
        let lonPaddingRight = span.longitudeDelta * right

        let topLeftCoordinateLat = center.latitude + (halfLatDelta + latPaddingTop)
        let topLeftCoordinateLon = center.longitude - (halfLonDelta + lonPaddingLeft)

        let bottomRightCoordinateLat = center.latitude - (halfLatDelta + latPaddingBottom)
        let bottomRightCoordinateLon = center.longitude + (halfLonDelta + lonPaddingRight)

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

    var paddedBoundingBoxNESW: (northEast: CLLocationCoordinate2D, southWest: CLLocationCoordinate2D) {
        let halfLatDelta = span.latitudeDelta / 2
        let halfLonDelta = span.longitudeDelta / 2

        let latPadding = span.latitudeDelta * 0.15
        let lonPadding = span.longitudeDelta * 0.15

        let cornerNorthEastLat = center.latitude + (halfLatDelta + latPadding)
        let cornerNorthEastLon = center.longitude + (halfLonDelta + lonPadding)

        let cornerSouthWestLat = center.latitude - (halfLatDelta + latPadding)
        let cornerSouthWestLon = center.longitude - (halfLonDelta + lonPadding)


        let northEast = CLLocationCoordinate2D(
            latitude: cornerNorthEastLat,
            longitude: cornerNorthEastLon
        )

        let southWest = CLLocationCoordinate2D(
            latitude: cornerSouthWestLat,
            longitude: cornerSouthWestLon
        )

        return (northEast, southWest)

    }

}
