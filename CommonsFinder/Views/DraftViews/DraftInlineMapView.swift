//
//  DraftInlineMapView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.03.26.
//

import CoreLocation
import GEOSwift
import GEOSwiftMapKit
import MapKit
import NukeUI
import SwiftUI

struct DraftMapItem: Identifiable {
    let id: String
    let imageRequest: ImageRequest?
    let coordinate: CLLocationCoordinate2D

    init(id: String, imageRequest: ImageRequest?, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.coordinate = coordinate
        self.imageRequest = imageRequest
    }

    init(latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
        id = UUID().uuidString
        coordinate = .init(latitude: latitude, longitude: longitude)
        imageRequest = nil
    }
}

struct DraftInlineMapView: View {
    let items: [DraftMapItem]
    var label: String?

    @State private var markerLabel: String?
    @State private var isMapSheetPresented = false

    var body: some View {

        let coordinatePoints = MultiPoint(points: items.map(\.coordinate).map(Point.init))

        if let paddedRegion = try? MKCoordinateRegion.init(containing: coordinatePoints, paddingFactor: 1, minPadding: items.count == 1 ? 500 : 150) {
            Button {
                isMapSheetPresented = true
            } label: {
                Map(initialPosition: .region(paddedRegion)) {
                    annotations
                }
                .mapControlVisibility(.hidden)
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .allowsHitTesting(false)
                .frame(height: 225)
                .clipShape(.rect(cornerRadius: 15))
            }
            .sheet(isPresented: $isMapSheetPresented) {
                NavigationStack {
                    Map(initialPosition: .region(paddedRegion)) {
                        annotations
                    }
                    .mapControls {
                        MapScaleView()
                        MapCompass()
                        MapPitchToggle()
                    }
                    .mapControlVisibility(.visible)
                    .mapStyle(
                        .standard(
                            pointsOfInterest: .excluding(
                                .bakery, .foodMarket, .restaurant, .cafe, .pharmacy, .automotiveRepair, .gasStation, .winery, .bakery, .nightlife, .mailbox, .store, .bank, .fitnessCenter))
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close", systemImage: "xmark") {
                                isMapSheetPresented = false
                            }
                        }
                    }
                }
            }


        }

    }

    @MapContentBuilder
    private var annotations: some MapContent {
        ForEach(items) { item in
            ImageArrowMapAnnotation(coordinate: item.coordinate, imageRequest: item.imageRequest)
        }
    }
}


#Preview("1 coordinate", traits: .previewEnvironment) {
    DraftInlineMapView(
        items: [
            .init(latitude: 51.509865, longitude: -0.118092)
        ], label: "Caption abc")
}

#Preview("multiple coordinates, same area", traits: .previewEnvironment) {
    DraftInlineMapView(
        items: [
            .init(latitude: 51.5159, longitude: -0.13),
            .init(latitude: 51.5152, longitude: -0.13),
            .init(latitude: 51.5151, longitude: -0.13),
            .init(latitude: 51.5159, longitude: -0.129),
        ], label: "Caption abc")
}

#Preview("multiple coordinates, long distance", traits: .previewEnvironment) {
    DraftInlineMapView(
        items: [
            .init(latitude: 51.5159, longitude: -0.13),
            .init(latitude: 51.5152, longitude: -0.13),
            .init(latitude: 51.5151, longitude: -0.13),
            .init(latitude: 52, longitude: -0.129),
        ], label: "Caption abc")
}
