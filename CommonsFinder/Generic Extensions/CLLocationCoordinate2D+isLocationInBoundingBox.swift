//
//  CLLocationCoordinate2D+isLocationInBoundingBox.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 28.11.25.
//

import CoreLocation

extension CLLocationCoordinate2D {
    func isLocationInBoundingBox(
        topLeft: CLLocationCoordinate2D, bottomRight: CLLocationCoordinate2D
    ) -> Bool {
        return latitude <= topLeft.latitude && latitude >= bottomRight.latitude && longitude >= topLeft.longitude && longitude <= bottomRight.longitude
    }
}
