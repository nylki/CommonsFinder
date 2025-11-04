//
//  MapView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 03.10.24.
//

import Accelerate
import CommonsAPI
import CoreLocation
import H3kit
import MapKit
import Nuke
import NukeUI
import SwiftUI
import os.log

struct MapView: View {
    @Environment(\.appDatabase) private var appDatabase
    @Environment(Navigation.self) private var navigation
    @Environment(MediaFileReactiveCache.self) private var mediaFileCache

    @Namespace private var namespace
    @Environment(\.isPresented) private var isPresented
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase

    @Environment(MapModel.self) private var mapModel


    /// this is either a media item or a wiki item
    private var scrollClusterItem: GeoItem? {
        guard let id = mapModel.selectedCluster?.mapSheetFocusedClusterItem.viewID(type: String.self) else {
            return nil
        }

        return mapModel.geoClusterTree.items[id]
    }

    private func openMediaFile(_ id: MediaFileInfo.ID) {
        if let mediaFileInfo = mediaFileCache[id] {
            navigation.viewFile(mediaFile: mediaFileInfo, namespace: namespace)
        } else {
            assertionFailure()
        }

    }

    var body: some View {
        @Bindable var mapModel = mapModel

        MapReader { mapProxy in
            Map(position: $mapModel.position) {
                clusterLayer

                UserAnnotation()

                switch scrollClusterItem {
                case .none:
                    EmptyMapContent()
                case .media(let mediaGeoItem):
                    Annotation("", coordinate: mediaGeoItem.coordinate, anchor: .center) {
                        MediaAnnotationView(
                            item: mediaFileCache[mediaGeoItem.id],
                            namespace: namespace,
                            isSelected: true,
                            onTap: { openMediaFile(mediaGeoItem.id) }
                        )
                        .id(mediaGeoItem.id)
                    }
                    .mapOverlayLevel(level: .aboveLabels)
                case .category(let category):
                    if let coordinate = category.coordinate {
                        Annotation(category.label ?? "", coordinate: coordinate, anchor: .center) {
                            // TODO: custom marker with image
                            WikiAnnotationView(item: category, isSelected: true) {
                                navigation.viewCategory(.init(category))
                            }
                            .id(category.geoRefID)
                        }
                        .mapOverlayLevel(level: .aboveLabels)
                    }
                }
            }

            .onMapCameraChange(frequency: .onEnd) { context in
                mapModel.setRegion(region: context.region)
                mapModel.refreshPlaces(context: context)
            }
            .onMapCameraChange(frequency: .continuous) { context in
                mapModel.setRegion(region: context.region)
                mapModel.refreshClusters()
            }
            .mapControls {
                MapCompass()
                MapScaleView(anchorEdge: .trailing)
                // MapUserLocationButton doesnt ask for permissions and thus doesnt work, bug?
                // check again maybe with iOS 19
                if mapModel.isLocationAuthorized {
                    MapUserLocationButton()
                }
            }
            .mapStyle(
                .standard(
                    elevation: .realistic,
                    emphasis: .automatic,
                    pointsOfInterest: .excludingAll,
                    showsTraffic: false
                )
            )
            .sheet(
                isPresented: mapModel.isMapSheetPresentedBinding,
                onDismiss: {
                    if navigation.mapPath.isEmpty {
                        // only clear the selected cluster if the dismiss comes from actively dismissing
                        // by the user, and not indirectly when a navigation mapPath update was pushed (eg. viewing an image)
                        mapModel.resetClusterSelection()
                    }
                }
            ) {
                if let model = mapModel.selectedCluster {
                    @Bindable var model = model
                    MapPopup(
                        model: model,
                        pickedItemType: mapModel.pickedItemType,
                        mapAnimationNamespace: namespace,
                        onClose: mapModel.resetClusterSelection
                    )
                    .id(model.cluster.id)
                    .presentationBackgroundInteraction(.enabled)
                    .presentationDetents(model.possibleDetents, selection: $model.selectedDetent)
                    .environment(mediaFileCache)
                    .environment(navigation)
                }

            }
        }
        .overlay(
            alignment: .top,
            content: {
                Picker("", selection: $mapModel.pickedItemType) {

                    Text("Locations")
                        .tag(MapItemType.wikiItem)

                    Text("Images")
                        .tag(MapItemType.mediaItem)
                }
                .pickerStyle(.segmented)
                .scenePadding([.top, .leading])
                .padding(.trailing, 100)
                .onChange(of: mapModel.pickedItemType) {
                    // TODO: set this implicitly in model or remember scrollPosition per type?
                    mapModel.selectedCluster?.mapSheetFocusedClusterItem = .init()
                }
            }
        )
        .overlay(alignment: .topTrailing) {
            /// This is the replacement for the MapUserLocationButton in the mapControls
            /// when the permission is not yet set
            if !mapModel.isLocationAuthorized {
                Button {
                    mapModel.goToUserLocation()
                } label: {
                    Image(systemName: "location")
                        .imageScale(.large)
                        .frame(width: 25, height: 33)

                }
                .tint(.blue)
                .glassButtonStyle()
                .labelStyle(.iconOnly)
                .scenePadding()

            }
        }
        .overlay {
            if mapModel.isRefreshingMap {
                ProgressView().progressViewStyle(.circular)
            }
        }
        .overlay(alignment: .bottomLeading) {
            //            #if DEBUG
            //                Text("\(mapModel.region?.diagonalMeters ?? 0.0)")
            //            #endif
        }
        // Hide navigation title to have a larger map but still set it for accessibility reasons
        // (eg. for Navigation or Screen Reader)
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .toolbarVisibility(verticalSizeClass == .compact ? .hidden : .automatic, for: .tabBar)
    }

    @MapContentBuilder
    private var clusterLayer: some MapContent {

        let clusters: ArraySlice<GeoCluster> =
            if let selectedCluster = mapModel.selectedCluster?.cluster {
                ArraySlice([selectedCluster] + mapModel.clusters.values)
            } else {
                ArraySlice(mapModel.clusters.values)
            }

        ForEach(clusters) { cluster in

            // FIXME: bound the meanCenter leave some padding for neighbor clusters

            let isSelected: Bool = mapModel.selectedCluster?.cluster.h3Index == cluster.h3Index


            if isSelected {
                let hull =
                    switch mapModel.pickedItemType {
                    case .mediaItem: mapModel.selectedCluster?.cluster.mediaHull
                    case .wikiItem: mapModel.selectedCluster?.cluster.categoryHull
                    }

                if let hull {
                    MapPolygon(hull)
                        .foregroundStyle(.clear)
                        .stroke(Color.accent, style: .init(lineWidth: 2, lineCap: .round, dash: [2, 6]))
                } else {
                    MapCircle(MKCircle(center: cluster.h3Center, radius: mapModel.currentResolution.approxCircleRadius))
                        .foregroundStyle(.clear)
                        .stroke(Color.accent, lineWidth: 2)
                }
            } else {

                switch mapModel.pickedItemType {
                case .mediaItem:
                    if cluster.mediaItems.isEmpty {
                        EmptyMapContent()
                    } else if cluster.mediaItems.count == 1,
                        let singleMediaItem = cluster.mediaItems.first,
                        let coordinate = singleMediaItem.coordinate
                    {
                        Annotation("", coordinate: coordinate, anchor: .center) {
                            MediaAnnotationView(
                                item: mediaFileCache[singleMediaItem.id],
                                namespace: namespace,
                                isSelected: false,
                                onTap: { openMediaFile(singleMediaItem.id) }
                            )
                        }
                    } else {
                        Annotation("", coordinate: cluster.meanCenter, anchor: .center) {
                            ClusterAnnotation(
                                pickedItemType: .mediaItem,
                                mediaCount: cluster.mediaItems.count,
                                wikiItemCount: cluster.categoryItems.count,
                                isSelected: isSelected
                            ) {
                                mapModel.selectCluster(cluster.h3Index)
                            }
                            .tag(cluster.h3Index)
                        }
                    }
                case .wikiItem:
                    if cluster.categoryItems.isEmpty {
                        EmptyMapContent()
                    } else if cluster.categoryItems.count == 1,
                        let singleCategory = cluster.categoryItems.first,
                        let coordinate = singleCategory.coordinate
                    {
                        Annotation(singleCategory.label ?? "", coordinate: coordinate, anchor: .center) {
                            WikiAnnotationView(item: singleCategory, isSelected: false) {
                                navigation.viewCategory(.init(singleCategory))
                            }
                            .id(singleCategory.geoRefID)
                        }
                        .mapOverlayLevel(level: .aboveLabels)
                        .tag(cluster.h3Index)
                    } else {
                        Annotation("", coordinate: cluster.meanCenter, anchor: .center) {
                            ClusterAnnotation(
                                pickedItemType: .wikiItem,
                                mediaCount: cluster.mediaItems.count,
                                wikiItemCount: cluster.categoryItems.count,
                                isSelected: isSelected
                            ) {
                                mapModel.selectCluster(cluster.h3Index)
                            }
                            .tag(cluster.h3Index)
                        }
                    }
                }


            }


        }
        .annotationTitles(.hidden)


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
