//
//  CLLocationManager+isLocationAutorized.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 10.11.25.
//

import CoreLocation
import Foundation

extension CLLocationManager {
    var isLocationAuthorized: Bool {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: true
        case .notDetermined, .restricted, .denied: false
        @unknown default: false
        }
    }
}
