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
    let fileTitle: String?

    @State private var mkMapItem: MKMapItem?
    @State private var humanReadableLocation: String?
    @State private var lookAroundScene: MKLookAroundScene?
    @State private var isLookAroundShowing = false

    @Environment(\.openURL) private var openURL

    private var location: CLLocation {
        CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    private var osmLink: URL? {
        let zoomLevel: Int = 16
        return URL(string: "https://www.openstreetmap.org/#map=\(zoomLevel)/\(coordinate.latitude)/\(coordinate.longitude)")
    }

    // TODO: geohack url: return "https://geohack.toolforge.org/geohack.php?pagename=File:\(fileTitle)&params=052.440597_N_0013.532672_E_globe:Earth_type:camera_heading:156.11&language=de"

    private var commonsMapLink: URL? {
        if let fileTitle {
            URL(string: "https://commons.wikimedia.org/wiki/File:\(fileTitle)#/maplink/0")
        } else {
            nil
        }
    }

    private var genericGeoLink: URL? {
        URL(string: "geo:\(coordinate.latitude),\(coordinate.longitude)")
    }

    private var omLink: URL? {
        URL(string: "om://map?v=1&ll=\(coordinate.latitude),\(coordinate.longitude)&n=\(humanReadableLocation ?? "")")
    }

    private func openInMapApp() {
        // TODO: switch external map via settings or "always ask" dialog
        // test installed apps via https://developer.apple.com/documentation/uikit/uiapplication/canopenurl(_:) ?

        let canOpenOrganicMaps = UIApplication.shared.canOpenURL(omLink!)
        logger.info("supports OrganicMaps: \(canOpenOrganicMaps)")
        if canOpenOrganicMaps, let omLink {
            openURL(omLink)
        } else if let mkMapItem {
            mkMapItem.openInMaps()
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

            Menu {
                mapMenuItems
            } label: {
                Text(humanReadableLocation ?? location.description)
                    .multilineTextAlignment(.leading)
            }
            .padding()
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
                let itemRequest = MKMapItemRequest(placeDescriptor: .init(representations: [.coordinate(coordinate)], commonName: nil))

                // TODO: potentially customize the mapItem
                let mapItem = try await itemRequest.mapItem
                self.humanReadableLocation = mapItem.address?.shortAddress ?? mapItem.name
                self.mkMapItem = mapItem

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
            if let mkMapItem {
                Marker(item: mkMapItem)
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
                logger.debug("Look Around scene fetching for \(humanReadableLocation ?? "")...")
                let lookAroundSceneRequest = MKLookAroundSceneRequest(coordinate: coordinate)
                lookAroundScene = try? await lookAroundSceneRequest.scene
                logger.debug("Look Around scene fetched for \(humanReadableLocation ?? ""): \(lookAroundScene == nil ? "false" : "true")")
            }
            .disabled(lookAroundScene == nil)

        Divider()
        if let osmLink {
            // TODO: use OSM-relation instead if it exists as structured-data statement!
            ShareLink(item: osmLink, subject: Text(humanReadableLocation ?? location.description)) {
                Label("Share OSM link...", systemImage: "square.and.arrow.up")
            }
        }

        Menu("More...") {
            if let commonsMapLink {
                Link(destination: commonsMapLink) {
                    Label("Open Kartographer Map", systemImage: "link")
                }
            }
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
    InlineMap(coordinate: .init(latitude: .init(48.8588), longitude: .init(2.2945)), fileTitle: nil)
}
