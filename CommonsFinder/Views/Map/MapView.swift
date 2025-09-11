//
//  MapView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 03.10.24.
//

import CommonsAPI
import CoreLocation
import H3kit
import MapKit
import Nuke
import NukeUI
import SwiftUI
import os.log

struct MapView: View {
    @Environment(Navigation.self) private var navigation
    @State private var mapModel = MapModel()

    @Namespace private var namespace
    @Environment(\.isPresented) private var isPresented
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase

    /// this is either a media item or a wiki item
    private var scrollClusterItem: (any GeoReferencable)? {
        guard let id = mapModel.focusedClusterItem.viewID(type: String.self) else {
            return nil
        }

        return mapModel.wikiItemClustering.items[id] ?? mapModel.mediaClustering.items[id]
    }

    var body: some View {
        MapReader { mapProxy in
            Map(position: $mapModel.position) {
                clusterLayer

                if let scrollClusterItem {
                    ItemAnnotation(item: scrollClusterItem)
                }

                UserAnnotation()
            }
            .mapControls {
                MapCompass()
                MapScaleView(anchorEdge: .trailing)
                // MapUserLocationButton doesnt ask for permissions and thus doesnt work, bug?
                // check again maybe with iOS 19
                // MapUserLocationButton()
            }
        }
        .overlay {
            if mapModel.isRefreshingMap {
                ProgressView().progressViewStyle(.circular)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button(
                "Locate Me",
                systemImage: "location.circle.fill",
                action: mapModel.followUserPosition
            )
            .labelStyle(.iconOnly)
            .font(.largeTitle)
            .foregroundStyle(Color.accentColor, .regularMaterial)
            .scenePadding()
        }
        .overlay(alignment: .bottomLeading) {
            #if DEBUG
                Text("\(mapModel.region?.diagonalMeters ?? 0.0)")
            #endif
        }
        .mapStyle(
            .standard(
                elevation: .realistic,
                emphasis: .automatic,
                pointsOfInterest: .excludingAll,
                showsTraffic: false
            )
        )
        .onMapCameraChange(frequency: .onEnd) { context in
            mapModel.setRegion(region: context.region)
            mapModel.refreshPlaces(context: context)
        }
        .onMapCameraChange(frequency: .continuous) { context in
            mapModel.setRegion(region: context.region)
            mapModel.refreshClusters()
        }
        .onChange(of: locale) {
            mapModel.locale = locale
        }
        // Hide navigation title to have a larger map but still set it for accessibility reasons
        // (eg. for Navigation or Screen Reader)
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .toolbarVisibility(verticalSizeClass == .compact ? .hidden : .automatic, for: .tabBar)


        .pseudoSheet(isPresented: $mapModel.isSheetPresented) {
            if let cellIndex = mapModel.selectedCluster,
                let rawMediaItems = mapModel.clusters[cellIndex]?.mediaItems,
                let wikiItems = mapModel.clusters[cellIndex]?.wikiItems
            {
                MapPopup(
                    clusterIndex: cellIndex,
                    scrollPosition: $mapModel.focusedClusterItem,
                    rawCategories: wikiItems,
                    rawMediaItems: rawMediaItems,
                    isPresented: $mapModel.isSheetPresented
                )
                // the .id makes sure we don't retain state of the previous cell
                // as this complicates things with scroll positions and selected states and is generally not desired for this custom sheet.
                .id(cellIndex)
            }
        }
    }


    @MapContentBuilder
    private var clusterLayer: some MapContent {
        ForEach(Array(mapModel.clusters.keys), id: \.self) { index in
            if let cluster = mapModel.clusters[index],
                let centerCoordinate = try? CLLocationCoordinate2D.h3CellCenter(h3Index: index)
            {

                let isSelected = index == mapModel.selectedCluster

                if isSelected {
                    MapCircle(MKCircle(center: centerCoordinate, radius: mapModel.currentResolution.approxCircleRadius))
                        .foregroundStyle(.clear)
                        .stroke(Color.accent, lineWidth: 2)

                } else {
                    Annotation("", coordinate: centerCoordinate, anchor: .center) {
                        ClusterAnnotation(
                            mediaCount: cluster.mediaItems.count,
                            wikiItemCount: cluster.wikiItems.count,
                            isSelected: isSelected
                        ) {
                            mapModel.selectCluster(index)
                        }
                        .tag(index)
                    }
                }


            } else {
                EmptyMapContent()
            }
        }
        .annotationTitles(.hidden)
    }
}

private struct ItemAnnotation: MapContent {
    let item: any GeoReferencable

    var body: some MapContent {
        if let lat = item.latitude, let lon = item.longitude {
            Annotation("", coordinate: .init(latitude: lat, longitude: lon), anchor: .center) {
                if let category = item as? Category {
                    WikiAnnotationView(item: category)
                        .id(category.geoRefID)

                } else if let imageItem = item as? GeoSearchFileItem {
                    MediaAnnotationView(item: imageItem)
                        .id(imageItem.geoRefID)
                }
            }
        }
    }
}


// TODO: unify both views (WikiAnnotationView + MediaAnnotationView) via Nuke.ImageRequest param when they stay identical
// for now this gives us some flexibility to differentiate both if useful or looks better
private struct WikiAnnotationView: View {
    @State private var isVisible = false
    let item: Category

    var body: some View {
        ZStack {
            if let imageRequest = item.thumbnailImage {
                LazyImage(request: imageRequest) { imageLoadingState in
                    if isVisible, let image = imageLoadingState.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .transition(.opacity)
                    }
                }
            } else {
                Color.accent.opacity(isVisible ? 1 : 0)
            }
        }
        .frame(width: 35, height: 35)
        .clipShape(.circle)
        .scaleEffect(isVisible ? 1 : 0.85, anchor: .center)
        .animation(.default, value: isVisible)
        .geometryGroup()
        .compositingGroup()
        .task {
            do {
                try await Task.sleep(for: .milliseconds(50))
                isVisible = true
            } catch {}
        }

    }
}

// TODO: unify both views (WikiAnnotationView + MediaAnnotationView) via Nuke.ImageRequest param when they stay identical
// for now this gives us some flexibility to differentiate both if useful or looks better
private struct MediaAnnotationView: View {
    let item: GeoSearchFileItem
    @State private var isVisible = false


    var body: some View {
        ZStack {
            if let title = item.title.split(separator: "File:").first,
                let resizedURL = try? URL.experimentalResizedCommonsImageURL(filename: String(title), maxWidth: 640)
            {
                // FIXME: url request to be identical on the map and in the sheet otherwise
                // we have two image separate network requests and a visible delay when display
                // the image on the map.
                LazyImage(request: Nuke.ImageRequest(url: resizedURL)) { imageLoadingState in
                    if isVisible, let image = imageLoadingState.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .transition(.opacity)
                    }
                }
            } else {
                Color.accent.opacity(isVisible ? 1 : 0)
            }
        }
        .frame(width: 35, height: 35)
        .clipShape(.circle)
        .scaleEffect(isVisible ? 1 : 0.85, anchor: .center)
        .animation(.default, value: isVisible)
        .geometryGroup()
        .compositingGroup()
        .task {
            do {
                try await Task.sleep(for: .milliseconds(50))
                isVisible = true
            } catch {}
        }

    }
}

extension MKCoordinateRegion {
    var metersInLatitude: Double {
        span.latitudeDelta * 111_320
    }

    /// area in m^2
    var area: Double {
        metersInLatitude * metersInLongitude
    }

    var metersInLongitude: Double {
        let metersPerDegreeLongitude = cos(center.latitude * .pi / 180.0) * 111_320
        return span.longitudeDelta * metersPerDegreeLongitude
    }

    var diagonalMeters: Double {
        sqrt(pow(metersInLatitude, 2) + pow(metersInLongitude, 2))
    }

    var boundingBox: (topLeft: CLLocationCoordinate2D, bottomRight: CLLocationCoordinate2D) {
        let halfLatDelata = span.latitudeDelta / 2
        let halfLonDelta = span.longitudeDelta / 2

        let topLeftCoordinateLat = center.latitude + halfLatDelata
        let topLeftCoordinateLon = center.longitude - halfLonDelta

        let bottomRightCoordinateLat = center.latitude - halfLatDelata
        let bottomRightCoordinateLon = center.longitude + halfLonDelta

        let topLeftCoordinate = CLLocationCoordinate2D(
            latitude: topLeftCoordinateLat,
            longitude: topLeftCoordinateLon
        )

        let bottomRightCoordinate = CLLocationCoordinate2D(
            latitude: bottomRightCoordinateLat,
            longitude: bottomRightCoordinateLon
        )

        return (topLeftCoordinate, bottomRightCoordinate)

    }
}

#Preview(traits: .previewEnvironment) {
    MapView()

}
