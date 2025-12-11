//
//  WrappedMapStyle.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.12.25.
//

import MapKit
import SwiftUI

enum WrappedMapStyle: String, CaseIterable, Identifiable {
    case standard
    case satellite

    var id: String {
        self.rawValue
    }

    static var allCases: [WrappedMapStyle] = [
        .standard, .satellite,
    ]

    var asMKMapStyle: MapStyle {
        switch self {
        case .standard:
            .standard(
                elevation: .automatic,
                emphasis: .automatic,
                pointsOfInterest: .excludingAll,
                showsTraffic: false
            )
        case .satellite:
            .hybrid(elevation: .realistic, pointsOfInterest: .excludingAll, showsTraffic: false)
        }
    }

    var labelText: String {
        switch self {
        case .standard:
            String(localized: "Standard", comment: "standard map style")
        case .satellite:
            String(localized: "Satellite", comment: "satellite map style")
        }
    }
}
