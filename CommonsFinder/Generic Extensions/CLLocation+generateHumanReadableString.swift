//
//  GeoLocationString.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 28.12.24.
//

import Foundation
@preconcurrency import MapKit

nonisolated extension CLLocationCoordinate2D {
    func reverseGeocodingRequest() async throws -> CLPlacemark? {
        let location = CLLocation(
            latitude: latitude,
            longitude: longitude
        )

        if #available(iOS 26.0, *) {
            let reverseRequest = MKReverseGeocodingRequest(location: location)
            // TODO: replace deprecated CLPlacemeark with MKMapItem? but less controll over water/ocean etc.
            return try await reverseRequest?.mapItems.first?.placemark
        } else {
            // Fallback on earlier versions
            return try await CLGeocoder().reverseGeocodeLocation(location).first
        }
    }

    func generateHumanReadableString(includeCountry: Bool = true) async throws -> String? {

        guard let placemark = try await reverseGeocodingRequest() else {
            return nil
        }

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

nonisolated extension CLLocation {
    func generateHumanReadableString(includeCountry: Bool = true) async throws -> String? {
        try await coordinate.generateHumanReadableString(includeCountry: includeCountry)
    }
}
