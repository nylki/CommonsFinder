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

enum InlineMapItemType {
    case mediaFile(MediaFile)
    case category(Category)
}

struct InlineMap: View {
    private let coordinate: CLLocationCoordinate2D
    private let shownItem: InlineMapItemType?
    private let knownName: String?
    private let mapPinStyle: MapPinStyle
    private let details: DetailSection

    @Environment(Navigation.self) private var navigation
    @Environment(MapModel.self) private var mapModel

    init(
        coordinate: CLLocationCoordinate2D,
        item: InlineMapItemType? = nil,
        knownName: String? = nil,
        mapPinStyle: MapPinStyle = .label,
        details: DetailSection = .label
    ) {
        self.coordinate = coordinate
        self.shownItem = item
        self.knownName = knownName
        self.mapPinStyle = mapPinStyle
        self.details = details

        switch item {
        case .mediaFile(let mediaFile):
            if coordinate != mediaFile.coordinate {
                logger.warning("coordinate and coordinate of showItem are not equal. This may indicate some underlying issue.")
            }
        case .category(let category):
            if coordinate != category.coordinate {
                logger.warning("coordinate and coordinate of showItem are not equal. This may indicate some underlying issue.")
            }
        case .none: break
        }
    }

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

    private var genericGeoLink: URL {
        URL(string: "geo-navigation:///place?coordinate=\(coordinate.latitude),\(coordinate.longitude)")!
    }

    private var omLink: URL? {
        URL(string: "om://map?v=1&ll=\(coordinate.latitude),\(coordinate.longitude)")
    }

    private func showOnMap() {

        do {
            switch shownItem {
            case .mediaFile(let mediaFile):
                try mapModel.showInCircle(mediaFile)
            case .category(let category):
                try mapModel.showInCircle(category)
            case .none:
                try mapModel.showInCircle(coordinate)
            }

            navigation.selectedTab = .map
        } catch {
            logger.error("Failed to show category on map \(error)")
        }
    }

    private func openInMapApp() {
        // TODO: switch external map via settings or "always ask" dialog
        // test installed apps via https://developer.apple.com/documentation/uikit/uiapplication/canopenurl(_:) ?

        //        let canOpenOrganicMaps = UIApplication.shared.canOpenURL(omLink!)
        //        logger.info("supports OrganicMaps: \(canOpenOrganicMaps)")
        logger.debug("opening map app with: \(genericGeoLink)")
        openURL(genericGeoLink)
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
                    geoReversedLabel = try await coordinate.generateHumanReadableString()
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
        Button("Show on Map", systemImage: "map", action: showOnMap)
        Button("Look Around", systemImage: "binoculars", action: openLookAround)
            .task {
                logger.debug("Look Around scene fetching for \(label)...")
                let lookAroundSceneRequest = MKLookAroundSceneRequest(coordinate: coordinate)
                lookAroundScene = try? await lookAroundSceneRequest.scene
                logger.debug("Look Around scene fetched for \(label): \(lookAroundScene == nil ? "false" : "true")")
            }
            .disabled(lookAroundScene == nil)

        Divider()

        Button("Open in Maps", systemImage: "arrow.up.forward.app", action: openInMapApp)

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
        return "\(latSign)\(latitude), \(lonSign)\(longitude)"
    }
}


#Preview {
    InlineMap(coordinate: .init(latitude: .init(48.8588), longitude: .init(2.2945)), item: nil)
}
