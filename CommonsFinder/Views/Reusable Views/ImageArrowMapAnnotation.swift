//
//  ImageArrowMapAnnotation.swift
//  CommonsFinder
//
//  Created by Tom on 10.07.26.
//

import CoreLocation
import GEOSwift
import GEOSwiftMapKit
import MapKit
import Nuke
import NukeUI
import SwiftUI

struct ImageArrowMapAnnotation: MapContent {
    let coordinate: CLLocationCoordinate2D
    let imageRequest: ImageRequest?

    private let imageDimension = 50.0
    private let triangleHeight = 15.0
    private let outlineWidth = 3.0
    private let imageShape = RoundedRectangle(cornerRadius: 7, style: .continuous)

    var body: some MapContent {
        Annotation("", coordinate: coordinate) {
            ZStack {
                Triangle()
                    .rotation(.degrees(180))
                    .fill(.white)
                    .frame(width: 25, height: triangleHeight)
                    .shadow(color: .black.opacity(0.38), radius: 4, x: 2, y: 2)
                    .offset(y: -triangleHeight / 2)


                LazyImage(request: imageRequest) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                            .frame(width: imageDimension, height: imageDimension)
                            .clipShape(imageShape)

                    } else {
                        imageShape.fill(Color.gray).frame(width: imageDimension, height: imageDimension)
                    }
                }
                .frame(width: imageDimension, height: imageDimension)
                .overlay {
                    imageShape.stroke(.white, lineWidth: outlineWidth)
                }
                .offset(y: -(imageDimension / 2) - (triangleHeight / 2) - outlineWidth)
            }
            .frame(width: imageDimension + outlineWidth, height: imageDimension + triangleHeight + outlineWidth)
            .compositingGroup()
            .geometryGroup()
        }
    }
}

#Preview {
    let coordinate = CLLocationCoordinate2D(latitude: 51.509865, longitude: -0.118092)
    let region = try! MKCoordinateRegion.init(containing: Point(coordinate), paddingFactor: 1, minPadding: 100)
    let imageRequest = ImageRequest(
        id: "1",
        data: {
            #if DEBUG
                UIImage(named: "debugDraftImage")?.jpegData(compressionQuality: 1) ?? .init()
            #endif
        })

    Map(initialPosition: .region(region)) {
        ImageArrowMapAnnotation(coordinate: coordinate, imageRequest: imageRequest)
    }
    .mapStyle(.hybrid)
}
