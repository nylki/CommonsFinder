//
//  LocationManager.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 20.02.25.
//

import CoreLocation
import SwiftUI
import os.log

@Observable
final class LocationManager {
    // Adapted from: https://holyswift.app/the-new-way-to-get-current-user-location-in-swiftu-tutorial/
    var location: CLLocation? = nil


    @ObservationIgnored
    private let locationManager = CLLocationManager()

    @ObservationIgnored
    private var liveTask: Task<Void, Never>?

    func requestUserAuthorization() async throws {
        locationManager.requestWhenInUseAuthorization()
    }

    func stopCurrentLocationUpdates() {
        liveTask?.cancel()
        liveTask = nil
    }

    func startCurrentLocationUpdates() async throws {
        stopCurrentLocationUpdates()

        liveTask = Task<Void, Never> {
            do {
                for try await locationUpdate in CLLocationUpdate.liveUpdates(.otherNavigation) {
                    guard let location = locationUpdate.location else { return }

                    self.location = location
                }
            } catch is CancellationError {
                logger.debug("Location updates cancelled.")
            } catch {
                logger.error("stopped receiving live updates \(error)")
            }
        }

    }

}
