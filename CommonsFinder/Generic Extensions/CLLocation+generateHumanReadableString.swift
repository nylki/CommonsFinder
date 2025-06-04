//
//  GeoLocationString.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 28.12.24.
//

import CoreLocation
import Foundation

extension CLLocation {
    func generateHumanReadableString(includeCountry: Bool = true) async throws -> String? {
        guard let placemark = await GeoPlacemarkCache.shared.getPlacemark(for: self) else { return nil }

        let primary: String? =
            if let water = placemark.ocean ?? placemark.inlandWater {
                water
            } else if let poi = placemark.name ?? placemark.areasOfInterest?.first {
                poi
            } else if let street = placemark.thoroughfare {
                street
            } else {
                nil
            }

        let secondary = placemark.locality
        let tertiary = includeCountry ? placemark.country : nil

        let humanReadableLocation = [primary, secondary, tertiary]
            .compactMap { $0 }
            .joined(separator: ", ")

        return humanReadableLocation
    }
}
