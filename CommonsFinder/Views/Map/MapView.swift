//
//  MapView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 03.10.24.
//

import Accelerate
import CommonsAPI
import CoreLocation
import GEOSwift
import GEOSwiftMapKit
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
    @Namespace private var mapScope
    @Environment(\.isPresented) private var isPresented
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase

    @Environment(MapModel.self) private var mapModel

    /// this is either a media item or a wiki item
    private var focusedMapSheetItem: GeoItem? {
        guard let id = mapModel.selectedMapItem?.mapSheetFocusedItem.viewID(type: String.self) else {
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

    private func handleLongPressGesture(gesturePoint: CGPoint) {
        guard let coordinate = mapModel.mapProxy?.convert(gesturePoint, from: .global) else {
            return
        }

        let point = Point(coordinate)

        if isZoomedIntoSelectedCluster {
            let pressedCluster: GeoCluster? = mapModel.clusters.values.first { cluster in
                let clusterGeometry: Geometry? =
                    switch mapModel.mapLayerMode {
                    case .categoryItems: cluster.categoryGeometry
                    case .mediaItem: cluster.mediaGeometry
                    }

                return if let clusterGeometry {
                    (try? clusterGeometry.contains(point)) ?? false
                } else {
                    false
                }
            }

            if let pressedCluster {
                mapModel.selectCluster(pressedCluster.h3Index)
            } else {
                mapModel.selectMapLocation(coordinate)
            }

        } else {
            mapModel.selectMapLocation(coordinate)
        }

    }

    var selectedCluster: GeoCluster? {
        (mapModel.selectedMapItem as? ClusterRepresentation)?.cluster
    }
    var selectedCircle: CircleRepresentation? {
        (mapModel.selectedMapItem as? CircleRepresentation)
    }
    var isZoomedIntoSelectedCluster: Bool {
        if let selectedClusterRes = selectedCluster?.h3Index.resolution {
            selectedClusterRes.rawValue < mapModel.currentResolution.rawValue
        } else {
            false
        }
    }


    var body: some View {
        @Bindable var mapModel = mapModel

        MapReader { mapProxy in

            Map(position: $mapModel.position, scope: mapScope) {
                clusterLayer

                UserAnnotation()

                if let selectedCircle {
                    MapCircle(MKCircle(center: selectedCircle.coordinate, radius: selectedCircle.radius))
                        .foregroundStyle(Color.accent.opacity(0.2))
                        .stroke(Color.accent, style: .init(lineWidth: 1, lineCap: .square, dash: [2, 6]))
                    Marker(coordinate: selectedCircle.coordinate) {
                    }
                }

                switch focusedMapSheetItem {
                case .none:
                    EmptyMapContent()
                case .media(let mediaGeoItem):
                    let label = mediaFileCache[mediaGeoItem.id]?.mediaFile.bestShortTitle.truncate(to: 80) ?? ""
                    Annotation(label, coordinate: mediaGeoItem.coordinate, anchor: .center) {
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
                        let label = category.label?.truncate(to: 80) ?? ""
                        Annotation(label, coordinate: coordinate, anchor: .center) {
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
            .task {
                mapModel.setProxy(mapProxy)
            }
            .gesture(MapPressGesture(longPressAt: handleLongPressGesture))
            .onMapCameraChange(frequency: .onEnd) { context in
                mapModel.setMapContext(context: context)
                mapModel.refreshPlaces(context: context)
            }
            .onMapCameraChange(frequency: .continuous) { context in
                mapModel.setMapContext(context: context)
                mapModel.updateItems()
            }
            .mapControls {
                MapCompass()
                let diagonalMeters: Double = mapModel.region?.diagonalMeters ?? .infinity
                if diagonalMeters < 7500 || mapModel.camera?.pitch != 0 {
                    MapPitchToggle()
                }

                MapScaleView()
            }
            .mapControlVisibility(.visible)
            .mapStyle(
                .standard(
                    elevation: .automatic,
                    emphasis: .automatic,
                    pointsOfInterest: .excludingAll,
                    showsTraffic: false
                )
            )
            .overlay(alignment: .trailing) {
                VStack {
                    MapUserLocateButtonCustom(mapModel: mapModel)
                    mapModeMenu
                }
                .scenePadding()
            }
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
                if let model = (mapModel.selectedMapItem as? MediaInClusterModel) {
                    @Bindable var model = model
                    MediaClusterSheet(
                        model: model,
                        mapAnimationNamespace: namespace,
                        onClose: mapModel.resetClusterSelection
                    )
                    .id(model.id)
                    .presentationBackgroundInteraction(.enabled)
                } else if let model = (mapModel.selectedMapItem as? CategoriesInClusterModel) {
                    @Bindable var model = model
                    CategoryClusterSheet(
                        model: model,
                        mapAnimationNamespace: namespace,
                        onClose: mapModel.resetClusterSelection
                    )
                    .id(model.id)
                    .presentationBackgroundInteraction(.enabled)
                } else if let model = (mapModel.selectedMapItem as? MediaAroundLocationModel) {
                    @Bindable var model = model
                    MediaCircleSheet(
                        model: model,
                        mapAnimationNamespace: namespace,
                        onClose: mapModel.resetClusterSelection
                    )
                    .id(model.id)
                    .presentationBackgroundInteraction(.enabled)
                } else if let model = (mapModel.selectedMapItem as? CategoriesAroundLocationModel) {
                    @Bindable var model = model
                    CategoryCircleSheet(
                        model: model,
                        mapAnimationNamespace: namespace,
                        onClose: mapModel.resetClusterSelection
                    )
                    .id(model.id)
                    .presentationBackgroundInteraction(.enabled)
                }

            }
        }
        .overlay {
            if mapModel.isRefreshingMap {
                ProgressView().progressViewStyle(.circular)
            }
        }
        // Hide navigation title to have a larger map but still set it for accessibility reasons
        // (eg. for Navigation or Screen Reader)
        .mapScope(mapScope)
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .toolbarVisibility(verticalSizeClass == .compact ? .hidden : .automatic, for: .tabBar)
    }

    @MapContentBuilder
    private var clusterLayer: some MapContent {
        let clusters: ArraySlice<GeoCluster> =
            if let selectedCluster {
                ArraySlice([selectedCluster] + mapModel.clusters.values)
            } else {
                ArraySlice(mapModel.clusters.values)
            }


        let selectedClusterHull =
            switch mapModel.mapLayerMode {
            case .mediaItem: selectedCluster?.mediaHull
            case .categoryItems: selectedCluster?.categoryHull
            }

        let selectedCircleLocation: CLLocation? =
            if let selectedCircle {
                CLLocation(
                    latitude: selectedCircle.coordinate.latitude,
                    longitude: selectedCircle.coordinate.longitude
                )
            } else { nil }

        let experimentalAlwaysShowHulls = false


        ForEach(clusters) { cluster in

            // TODO: clean up this logic to be easier to read (maybe switch by selected item first, if its a cluster or circle and lay out the logic in sub-funcs for each case)

            let hull =
                switch mapModel.mapLayerMode {
                case .mediaItem: cluster.mediaHull
                case .categoryItems: cluster.categoryHull
                }

            let isSelected: Bool = selectedCluster?.h3Index == cluster.h3Index

            //            let containsFocusedSheetItem = if let focusedItemID = focusedMapSheetItem {
            //                switch focusedItemID {
            //                case .media:
            //                    Set(cluster.mediaItems.map(\.geoRefID)).contains(focusedItemID.geoRefID)
            //                case .category:
            //                    Set(cluster.categoryItems.map(\.geoRefID)).contains(focusedItemID.geoRefID)
            //                }
            //            } else {
            //                false
            //            }

            let isContainedInSelectedCluster: Bool =
                if let selectedClusterRes = selectedCluster?.h3Index.resolution,
                    let parent = try? H3.cellToParent(cell: cluster.h3Index, parentRes: selectedClusterRes)
                {
                    parent == selectedCluster?.h3Index
                } else {
                    false
                }


            lazy var isContainedInSelectedRadius: Bool = {
                if let selectedCircle, let selectedCircleLocation {
                    // FIXME: move to a helper func
                    let clusterHullCenter = CLLocation(
                        latitude: hull.coordinate.latitude,
                        longitude: hull.coordinate.longitude
                    )
                    return clusterHullCenter.distance(from: selectedCircleLocation) < selectedCircle.radius
                } else {
                    return false
                }
            }()

            let isZoomedIntoSelected =
                if let selectedClusterRes = selectedCluster?.h3Index.resolution {
                    selectedClusterRes.rawValue < mapModel.currentResolution.rawValue
                } else {
                    false
                }


            if isSelected {
                if let selectedClusterHull {
                    MapPolygon(selectedClusterHull)
                        .foregroundStyle(Color.accent.opacity(isZoomedIntoSelectedCluster ? 0.1 : 0.2))
                        .stroke(
                            Color.accent.opacity(isZoomedIntoSelectedCluster ? 0.35 : 1),
                            style: .init(lineWidth: 1, lineCap: .square, dash: [2, 6])
                        )
                } else {
                    MapCircle(MKCircle(center: cluster.h3Center, radius: mapModel.currentResolution.approxCircleRadius))
                        .foregroundStyle(.clear)
                        .stroke(Color.accent, lineWidth: 2)
                }
            } else if isContainedInSelectedCluster {
                MapPolygon(hull)
                    .foregroundStyle(Color.accent.opacity(0.2))
                    .stroke(Color.accent, style: .init(lineWidth: 1, lineCap: .square, dash: [2, 6]))
            } else if !isContainedInSelectedRadius {
                switch mapModel.mapLayerMode {
                case .mediaItem:
                    if cluster.mediaItems.isEmpty {
                        EmptyMapContent()
                    } else if cluster.mediaItems.count == 1,
                        let singleMediaItem = cluster.mediaItems.first,
                        let coordinate = singleMediaItem.coordinate
                    {
                        /// single Image
                        let mediaFileInfo = mediaFileCache[singleMediaItem.id]
                        Annotation(mediaFileInfo?.mediaFile.bestShortTitle.truncate(to: 80) ?? "", coordinate: coordinate, anchor: .center) {
                            MediaAnnotationView(
                                item: mediaFileCache[singleMediaItem.id],
                                namespace: namespace,
                                isSelected: false,
                                onTap: { mapModel.selectCluster(cluster.h3Index) }
                            )
                        }
                    } else {
                        // multiple images
                        Annotation("", coordinate: cluster.meanCenterMedia, anchor: .center) {
                            ClusterAnnotation(
                                pickedItemType: .mediaItem,
                                mediaCount: cluster.mediaItems.count,
                                wikiItemCount: cluster.categoryItems.count,
                                isSelected: isSelected
                            ) {
                                mapModel.selectCluster(cluster.h3Index)
                            }
                        }
                    }
                case .categoryItems:
                    if cluster.categoryItems.isEmpty {
                        EmptyMapContent()
                    } else if cluster.categoryItems.count == 1,
                        let singleCategory = cluster.categoryItems.first,
                        let coordinate = singleCategory.coordinate
                    {
                        // single category
                        Annotation(singleCategory.label ?? "", coordinate: coordinate, anchor: .center) {
                            WikiAnnotationView(item: singleCategory, isSelected: false) {
                                mapModel.selectCluster(cluster.h3Index)
                            }
                            .id(singleCategory.geoRefID)
                        }
                        .mapOverlayLevel(level: .aboveLabels)
                    } else {
                        if experimentalAlwaysShowHulls {
                            MapPolygon(hull)
                                .foregroundStyle(Color.accent.opacity(0.2))
                                .stroke(Color.accent, style: .init(lineWidth: 1, lineCap: .square, dash: [2, 6]))
                        }


                        // multiple categories
                        Annotation("", coordinate: cluster.meanCenterCategories, anchor: .center) {
                            ClusterAnnotation(
                                pickedItemType: .categoryItems,
                                mediaCount: cluster.mediaItems.count,
                                wikiItemCount: cluster.categoryItems.count,
                                isSelected: isSelected
                            ) {
                                mapModel.selectCluster(cluster.h3Index)
                            }
                        }
                    }
                }
            }
        }
        .annotationTitles(mapModel.selectedMapItem == nil ? .automatic : .hidden)
    }

    private var mapModeMenu: some View {
        Menu {
            Text("Map Mode")
            Divider()
            Button {
                mapModel.selectMapMode(.categoryItems)
            } label: {
                Label("Locations", systemImage: "tag.fill")

            }
            .labelStyle(.iconOnly)

            Button {
                mapModel.selectMapMode(.mediaItem)
            } label: {
                Label("Images", systemImage: "photo")
            }
            .labelStyle(.iconOnly)
        } label: {
            switch mapModel.mapLayerMode {
            case .categoryItems:
                Image(systemName: "tag.fill")
                    .imageScale(.large)
                    .frame(width: 25, height: 33)
            case .mediaItem:
                Image(systemName: "photo")
                    .imageScale(.large)
                    .frame(width: 25, height: 33)
            }
        }
        .glassButtonStyle()
    }
}

#Preview(traits: .previewEnvironment) {
    MapView()

}
