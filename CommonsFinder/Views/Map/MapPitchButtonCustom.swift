//
//  MapPitchButtonCustom.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.11.25.
//


import MapKit
import SwiftUI

struct MapPitchButtonCustom: View {
    let mapModel: MapModel

    var body: some View {
        Button(action: togglePitch) {
            Image(systemName: mapModel.camera?.pitch == 0 ? "view.3d" : "view.2d")
                .imageScale(.large)
                .frame(width: 25, height: 33)
        }
    }

    private func togglePitch() {
        let shouldKeepFollowingUserLocation = mapModel.position.followsUserLocation
        let shouldKeepFollowingUserHeading = mapModel.position.followsUserHeading
        guard var newCamera = mapModel.camera else {
            return
        }

        if mapModel.camera?.pitch == 0 {
            newCamera.pitch = 60
        } else {
            newCamera.pitch = 0
        }

        withAnimation(.easeInOut(duration: 0.1)) {
            mapModel.position = .camera(newCamera)
        }


        if shouldKeepFollowingUserLocation {
            Task {
                mapModel.position = .userLocation(followsHeading: shouldKeepFollowingUserHeading, fallback: mapModel.position)
            }
        }
    }


}
