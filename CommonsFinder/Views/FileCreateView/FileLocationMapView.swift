//
//  FileLocationMapView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.03.26.
//

import CoreLocation
import SwiftUI
import MapKit
import GEOSwift
import GEOSwiftMapKit

struct FileLocationMapView: View {
    let coordinates: [CLLocationCoordinate2D]
    var label: String?

    @State private var markerLabel: String?

    var body: some View {
        
        if let paddedRegion = try? MKCoordinateRegion.init(containing:  MultiPoint(points: coordinates.map(Point.init)), paddingFactor: 0.2, minPadding: 500) {
            Map(initialPosition: .region(paddedRegion)) {
                if coordinates.count == 1, let coordinate = coordinates.first {
                    Marker(label ?? "", coordinate: coordinate)
                } else {
                    ForEach(coordinates, id: \.hashValue) { coordinate in
                        Annotation(coordinate: coordinate) {
                            Color.red.opacity(0.6)
                                .frame(width: 10, height: 10)
                                .clipShape(.circle)
                                .overlay {
                                    Circle()
                                        .stroke(lineWidth: 2)
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                        } label: {}

                    }
                }

                
            }
            .mapControlVisibility(.hidden)
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .allowsHitTesting(false)
            .frame(height: 200)
            .clipShape(.rect(cornerRadius: 15))
        }

    }
}


#Preview(traits: .previewEnvironment) {
    FileLocationMapView(coordinates: [.init(latitude: 0, longitude: 0)])
}

#Preview(traits: .previewEnvironment) {
    FileLocationMapView(coordinates: [.init(latitude: 0, longitude: 0.1), .init(latitude: 0.1, longitude: 0), .init(latitude: 0.2, longitude: 0.325), .init(latitude: -5, longitude: 0.075)])
}
