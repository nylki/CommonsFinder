//
//  LocationHandling.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 16.03.26.
//


import Foundation
import CoreLocation

    nonisolated enum LocationHandling: Codable, Equatable, Hashable {
        /// location data will be removed from EXIF if it exists inside the binary and won't be added to wikitext or structured data
        case noLocation
        /// location data from EXIF will be used for wikitext and structured data
        case exifLocation
        /// user defined location data will be used for wikitext and structured data, EXIF-location will be overwritten by user defined location
        case userDefinedLocation(latitude: CLLocationDegrees, longitude: CLLocationDegrees, precision: CLLocationDegrees)
    }
