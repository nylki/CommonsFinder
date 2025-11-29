//
//  CustomMapUserLocateButton.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 10.11.25.
//

import MapKit
import SwiftUI

struct MapUserLocateButtonCustom: View {
    let mapModel: MapModel

    private var defaultLocation: MapCameraPosition {
        if let currentCamera = mapModel.camera {
            .camera(currentCamera)
        } else {
            .automatic
        }
    }

    private let positionFollowed = MapCameraPosition.userLocation(followsHeading: false, fallback: .automatic)
    private let positionAndHeadingFollowed = MapCameraPosition.userLocation(followsHeading: true, fallback: .userLocation(followsHeading: false, fallback: .automatic))

    private var currentPosition: MapCameraPosition {
        mapModel.position
    }

    var body: some View {
        let config: (iconName: String, nextPosition: MapCameraPosition) =
            if currentPosition.followsUserLocation, currentPosition.followsUserHeading {
                (iconName: "location.north.line.fill", nextPosition: defaultLocation)
            } else if currentPosition.followsUserLocation {
                (iconName: "location.fill", nextPosition: positionAndHeadingFollowed)
            } else {
                (iconName: "location", nextPosition: positionFollowed)
            }

        Button {
            withAnimation {
                if !mapModel.locationManager.isLocationAuthorized {
                    requestPermissionAndLocateUser()
                } else {
                    mapModel.position = config.nextPosition
                }
            }
        } label: {
            Image(systemName: config.iconName)
                .contentTransition(.symbolEffect(.replace))
                .imageScale(.large)
                .frame(width: 25, height: 33)
                .animation(.default, value: currentPosition)
        }
        .labelStyle(.iconOnly)
        .glassButtonStyle()


    }

    /// Continuously tracks and follows tne position on the map (i.e. Navigation mode)
    private func requestPermissionAndLocateUser() {
        mapModel.locationManager.activityType = .otherNavigation
        mapModel.locationManager.distanceFilter = 7
        mapModel.locationManager.requestWhenInUseAuthorization()
        mapModel.position = positionFollowed
    }
}
