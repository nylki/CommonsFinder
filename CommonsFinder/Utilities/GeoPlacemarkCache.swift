//
//  GeoPlacemarkCache.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 28.12.24.
//

import CoreLocation
import Foundation
import Lock
import os.log

final class GeoPlacemarkCache {
    static let shared = GeoPlacemarkCache()

    private let lock = AsyncLock()
    private var cache: [CLLocation: CLPlacemark] = [:]

    func getPlacemark(for location: CLLocation) async -> CLPlacemark? {
        if let placemark = cache[location] {
            return placemark
        }

        // To avoid accessing the expensive CLGeocoder.reverseGeoLocation simultaneously
        // we only allow one caller at a time to get here.
        await lock.lock()

        do {
            if let placemark = try await CLGeocoder().reverseGeocodeLocation(location).first {
                cache[location] = placemark
                lock.unlock()
                return placemark
            }
        } catch {
            logger.warning("failed to reverse geo location \(location). error: \(error)")
        }


        return nil
    }
}
