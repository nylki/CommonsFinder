//
//  MapModel.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 28.02.25.
//

import AsyncAlgorithms
import CommonsAPI
import CoreLocation
import H3kit
import MapKit
import Nuke
import OrderedCollections
import SwiftUI
import os.log

@Observable final class MapModel {
    var position: MapCameraPosition = .automatic
    private(set) var region: MKCoordinateRegion?
    private(set) var rect: MKMapRect?
    private(set) var camera: MapCamera?

    private let navigation: Navigation
    private let appDatabase: AppDatabase

    private(set) var mapLayerMode: MapLayerMode = .categoryItems

    @ObservationIgnored
    private var fetchTask: Task<Void, Error>?

    private var refreshRegionTask: Task<Void, Never>?
    private(set) var lastRefreshedRegions: OrderedSet<MKCoordinateRegion> = .init()
    private(set) var currentRefreshingRegion: MKCoordinateRegion?
    var isRefreshingMap: Bool { currentRefreshingRegion != nil }

    // FIXME: constantly filling the cluster collections may end up eating all memory
    // we need to prune them when they get too big, based to distance to current region
    @ObservationIgnored
    private(set) var geoClusterTree = GeoClusterTree()

    private(set) var clusters: [H3Index: GeoCluster] = .init()
    private var isMapSheetPresented: Bool = false

    init(appDatabase: AppDatabase, navigation: Navigation) {
        self.appDatabase = appDatabase
        self.navigation = navigation
    }

    /// To be used as the binding in the sheet initializer
    var isMapSheetPresentedBinding: Binding<Bool> {
        .init(
            get: {
                self.isMapSheetPresented && self.navigation.mapPath.isEmpty == true
            },
            set: { newValue in
                if self.navigation.mapPath.isEmpty == true {
                    self.isMapSheetPresented = newValue
                }
            })
    }

    private(set) var selectedCluster: ClusterModel?


    @ObservationIgnored
    private var locationTrack: Task<Void, Never>?

    var locationManager: CLLocationManager = .init()
    var isLocationAuthorized: Bool {
        locationManager.isLocationAuthorized
    }

    /// in meter
    private let imageVisibilityThreshold: Double = 4000
    private let wikiItemVisibilityThreshold: Double = 40_000

    var currentResolution: H3.Resolution {
        if let region {
            H3.bestH3Resolution(forScreenArea: region.area)
        } else {
            .zero
        }
    }

    func selectMapMode(_ mode: MapLayerMode) {
        isMapSheetPresented = false
        selectedCluster?.mapSheetFocusedClusterItem = .init()
        mapLayerMode = mode
        refreshClusters()
    }

    func setMapContext(context: MapCameraUpdateContext) {
        self.region = context.region
        self.rect = context.rect
        self.camera = context.camera
    }


    func selectCluster(_ index: H3Index) {
        guard let cluster = clusters[index] else {
            assertionFailure()
            return
        }

        selectedCluster = .init(cluster: cluster)
        isMapSheetPresented = true
        // TODO: fetch items in circle radius if items > max (500?)
    }

    func resetClusterSelection() {
        isMapSheetPresented = false
        selectedCluster = nil
    }

    func refreshClusters() {
        guard let region else { return }

        let clock = ContinuousClock()
        let elapsed = clock.measure {
            clusters = geoClusterTree.clusters(
                topLeft: region.boundingBox.topLeft,
                bottomRight: region.boundingBox.bottomRight,
                resolution: currentResolution
            )

            /// update data of selected cluster if we refresh the cluster info (eg. more items) otherwise if the bbox cluster don't have
            /// it (eg. zoomed in), we retain it for display and to let the user keep interacting with it.
            if let selectedIdx = selectedCluster?.cluster.h3Index, let updatedSelectedCluster = clusters[selectedIdx] {
                selectedCluster?.cluster = updatedSelectedCluster
            }

        }

        //        logger.debug("refreshClusters took \(elapsed)")

        if elapsed > .milliseconds(4) {
            logger.critical("refreshClusters took long! \(elapsed)")
        }
    }

    private func fetchDataForCurrentRegion() {
        guard let region else { return }

        fetchTask?.cancel()
        fetchTask = Task {
            try await Task.sleep(for: .milliseconds(500))
            currentRefreshingRegion = region
            defer { currentRefreshingRegion = nil }

            logger.info("Map: refreshing started...")

            async let wikiItemsTask = fetchWikiItems(region: region, maxDiagonalMapLength: wikiItemVisibilityThreshold)
            async let mediaTask = fetchMediaFiles(region: region, maxDiagonalMapLength: imageVisibilityThreshold)
            let (wikidataItems, mediaItems) = await (wikiItemsTask, mediaTask)

            var items: [GeoItem] = []

            for wikidataItem in wikidataItems {
                items.append(.category(wikidataItem))
            }
            for mediaItem in mediaItems {
                items.append(.media(mediaItem))
            }

            geoClusterTree.add(items)
            refreshClusters()

            lastRefreshedRegions.append(region)
            logger.info("Map: refreshing finished.")
        }
    }

    func stopFollowingUserLocation() {
        locationTrack?.cancel()
        locationTrack = nil
    }

    func followUserLocation() {
        locationTrack?.cancel()
        locationTrack = Task<Void, Never> {
            let currentCamera = position.camera
            do {
                for try await locationUpdate in CLLocationUpdate.liveUpdates(.otherNavigation) {
                    try Task.checkCancellation()
                    guard let location = locationUpdate.location else { continue }

                    position = .camera(
                        .init(
                            centerCoordinate: location.coordinate,
                            distance: currentCamera?.distance ?? region?.diagonalMeters ?? 1000,
                            heading: currentCamera?.heading ?? 0,
                            pitch: currentCamera?.pitch ?? 0
                        ))

                }
            } catch is CancellationError {
                logger.debug("Location updates cancelled.")
            } catch {
                logger.error("stopped receiving live updates \(error)")
            }
        }
    }

    func refreshPlaces(context: MapCameraUpdateContext) {
        let region = context.region
        guard context.region.diagonalMeters < 500000 else { return }


        guard isRegionDiffSignificant(oldRegion: currentRefreshingRegion, newRegion: region) else {
            return
        }

        let hasNotBeenFetched = lastRefreshedRegions.allSatisfy { oldRegion in
            isRegionDiffSignificant(oldRegion: oldRegion, newRegion: region)
        }
        guard hasNotBeenFetched else { return }

        fetchDataForCurrentRegion()
    }
}

private func fetchWikiItems(region: MKCoordinateRegion, maxDiagonalMapLength: Double) async -> [Category] {
    guard region.diagonalMeters < maxDiagonalMapLength else { return [] }

    let halfLatDelata = region.span.latitudeDelta / 2
    let halfLonDelta = region.span.longitudeDelta / 2

    let cornerNorthEastLat = region.center.latitude + halfLatDelata
    let cornerNorthEastLon = region.center.longitude + halfLonDelta

    let cornerSouthWestLat = region.center.latitude - halfLatDelata
    let cornerSouthWestLon = region.center.longitude - halfLonDelta

    do {
        let getAllItems = region.diagonalMeters < 7500

        let items: [Category] = try await API.shared
            .getWikidataItemsInBoundingBox(
                cornerSouthWest: .init(latitude: cornerSouthWestLat, longitude: cornerSouthWestLon),
                cornerNorthEast: .init(latitude: cornerNorthEastLat, longitude: cornerNorthEastLon),
                isAreaOptional: getAllItems,
                isCategoryOptional: getAllItems,
                languageCode: Locale.current.wikiLanguageCodeIdentifier,
                limit: getAllItems ? 10000 : 200
            )
            .map { .init(apiItem: $0) }

        logger.info("wikidata item count: \(items.count)")

        return items
    } catch {
        logger.error("Failed to get files around coordinate \(error), maybe canceled.")
        return []
    }
}

private func fetchMediaFiles(region: MKCoordinateRegion, maxDiagonalMapLength: Double) async -> [GeoSearchFileItem] {
    guard region.diagonalMeters < maxDiagonalMapLength else { return [] }
    do {
        let boundingBox = region.boundingBox

        let items: [GeoSearchFileItem] = try await API.shared
            .geoSearchFiles(
                topLeft: boundingBox.topLeft,
                bottomRight: boundingBox.bottomRight
            )


        guard !items.isEmpty else {
            return []
        }

        return items

    } catch {
        logger.error("Failed to get files around coordinate \(error), maybe canceled.")
        return []
    }
}

private func isRegionDiffSignificant(oldRegion: MKCoordinateRegion?, newRegion: MKCoordinateRegion) -> Bool {
    guard let oldRegion else { return true }

    let isAreaDiffSignificant: Bool
    let isCenterDiffSignificant: Bool

    // Compare center and area (zoom) relative to the box dimensions
    // to determine if a map was significant

    let lastCenter = CLLocation(
        latitude: newRegion.center.latitude,
        longitude: newRegion.center.longitude
    )
    let currentCenter = CLLocation(
        latitude: oldRegion.center.latitude,
        longitude: oldRegion.center.longitude
    )

    let locationDiff = currentCenter.distance(from: lastCenter)
    let relCenterDiff = locationDiff / oldRegion.diagonalMeters

    let relAreaDiff = oldRegion.area / newRegion.area

    // NOTE: The thresholds are roughly estimated and may be adjusted if necessary
    isAreaDiffSignificant = abs(1 - relAreaDiff) > 0.25
    isCenterDiffSignificant = relCenterDiff > 0.05

    //                    logger.info("relCenterDiff \(relCenterDiff) \(isCenterDiffSignificant ? "significant!" : "")")
    //                    logger.info("relAreaDiff \(relAreaDiff) \(isAreaDiffSignificant ? "significant!" : "")")

    return isAreaDiffSignificant || isCenterDiffSignificant

}

nonisolated
    extension MediaGeoItem: GeoReferencable
{
    var geoRefID: GeoRefID {
        self.id
    }

    var latitude: Double? { lat }
    var longitude: Double? { lon }
}

nonisolated extension Category: GeoReferencable {
    var geoRefID: GeoRefID {
        let geoRefID = wikidataId ?? commonsCategory
        assert(geoRefID != nil)
        return geoRefID!
    }
}
