import GeoToolbox
@preconcurrency import MapKit
//
//  InlineMap.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 12.12.24.
//
import SwiftUI
import os.log

struct InlineMap: View {
    let coordinate: CLLocationCoordinate2D
    var knownName: String? = nil
    var mapPinStyle: MapPinStyle = .label
    var details: DetailSection = .label

    enum MapPinStyle {
        case label
        case pinOnly
    }

    enum DetailSection {
        case none
        case label
    }

    @State private var geoReversedLabel: String?
    @State private var lookAroundScene: MKLookAroundScene?
    @State private var isLookAroundShowing = false
    @State private var mapItem: MKMapItem?

    private var label: String {
        knownName ?? geoReversedLabel ?? "\(coordinate.latitude), \(coordinate.longitude)"
    }

    @Environment(\.openURL) private var openURL

    private var location: CLLocation {
        CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    private var osmLink: URL? {
        let zoomLevel: Int = 16
        return URL(string: "https://www.openstreetmap.org/#map=\(zoomLevel)/\(coordinate.latitude)/\(coordinate.longitude)")
    }

    private var genericGeoLink: URL? {
        URL(string: "geo:\(coordinate.latitude),\(coordinate.longitude)")
    }

    private var omLink: URL? {
        URL(string: "om://map?v=1&ll=\(coordinate.latitude),\(coordinate.longitude)&n=\(label)")
    }

    private func openInMapApp() {
        // TODO: switch external map via settings or "always ask" dialog
        // test installed apps via https://developer.apple.com/documentation/uikit/uiapplication/canopenurl(_:) ?

        let canOpenOrganicMaps = UIApplication.shared.canOpenURL(omLink!)
        logger.info("supports OrganicMaps: \(canOpenOrganicMaps)")
        if canOpenOrganicMaps, let omLink {
            openURL(omLink)
        } else {
            MKMapItem(placemark: .init(location: location, name: label, postalAddress: nil)).openInMaps()
        }
    }

    private func openLookAround() {
        isLookAroundShowing = true

    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Menu {
                mapMenuItems
            } label: {
                map
            }

            switch details {
            case .none:
                EmptyView()
            case .label:
                Menu {
                    mapMenuItems
                } label: {
                    Text(label)
                        .multilineTextAlignment(.leading)
                }
                .padding()
            }

        }
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: 8))

        .lookAroundViewer(
            isPresented: $isLookAroundShowing,
            initialScene: lookAroundScene,
            allowsNavigation: true,
            pointsOfInterest: .all
        )
        .task {
            do {
                if knownName == nil {
                    let request = MKReverseGeocodingRequest(location: .init(latitude: coordinate.latitude, longitude: coordinate.longitude))


                    if let item = try await request?.mapItems.first {
                        geoReversedLabel = item.address?.shortAddress ?? item.name
                    }

                }
            } catch {

            }

        }

    }

    @ViewBuilder
    private var map: some View {
        let halfKmRadius = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 500,
            longitudinalMeters: 500
        )
        Map(initialPosition: .region(halfKmRadius)) {
            switch mapPinStyle {
            case .label:
                Marker(label, coordinate: coordinate)
            case .pinOnly:
                Marker("", coordinate: coordinate)
            }
        }
        .mapControlVisibility(.hidden)
        .allowsHitTesting(false)
        .frame(height: 150)
    }

    @ViewBuilder
    private var mapMenuItems: some View {
        Button("Open in Map App", systemImage: "map", action: openInMapApp)
        Button("Look Around", systemImage: "binoculars", action: openLookAround)
            .task {
                logger.debug("Look Around scene fetching for \(label)...")
                let lookAroundSceneRequest = MKLookAroundSceneRequest(coordinate: coordinate)
                lookAroundScene = try? await lookAroundSceneRequest.scene
                logger.debug("Look Around scene fetched for \(label): \(lookAroundScene == nil ? "false" : "true")")
            }
            .disabled(lookAroundScene == nil)

        Divider()
        if let osmLink {
            // TODO: use OSM-relation instead if it exists as structured-data statement!
            ShareLink(item: osmLink, subject: Text(label)) {
                Label("Share OSM link...", systemImage: "square.and.arrow.up")
            }
        }

        Menu("More...") {
            Button("Copy Coordinates", systemImage: "clipboard") {
                UIPasteboard.general.string = coordinate.coordinateString
            }
        }
    }
}

extension CLLocationCoordinate2D {
    fileprivate var coordinateString: String {
        let latSign = latitude.sign == .minus ? "-" : ""
        let lonSign = longitude.sign == .minus ? "-" : ""
        return "\(latSign)\(latitude) \(lonSign)\(longitude)"
    }
}


#Preview {
    InlineMap(coordinate: .init(latitude: .init(48.8588), longitude: .init(2.2945)))
}
