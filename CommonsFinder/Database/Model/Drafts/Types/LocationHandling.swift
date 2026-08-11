//
//  LocationHandling.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 16.03.26.
//


import CoreLocation
import Foundation

nonisolated enum LocationHandling: Codable, Equatable, Hashable {
    /// location data will be removed from EXIF if it exists inside the binary and won't be added to wikitext or structured data
    case noLocation
    /// location data from EXIF will be used for wikitext and structured data
    case exifLocation

    /// user defined location data will be used for wikitext and structured data.
    /// NOTE:  for correctness and to avoid misinterpretation of the uploaded file, **EXIF-location will be deleted** in this case
    /// since the location data does not come from GPS, but the original GPS data is not preferred to be kept (may contain sensitiv, inaccurate location etc.)
    case userDefinedLocation(latitude: CLLocationDegrees, longitude: CLLocationDegrees, precision: CLLocationDegrees)
}
