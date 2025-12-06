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

enum MapError: Error {
    case itemWithoutCoordinateCannotBeShownOnMap
}

@Observable final class MapModel {
    var position: MapCameraPosition = .automatic
    private(set) var region: MKCoordinateRegion?
    private(set) var rect: MKMapRect?
    private(set) var camera: MapCamera?

    private let navigation: Navigation
    private let appDatabase: AppDatabase
    private let mediaFileCache: MediaFileReactiveCache

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

    private(set) var selectedMapItem: SelectedMapItemModel?

    private(set) var mapProxy: MapProxy?

    init(appDatabase: AppDatabase, navigation: Navigation, mediaFileCache: MediaFileReactiveCache) {
        self.appDatabase = appDatabase
        self.mediaFileCache = mediaFileCache
        self.navigation = navigation

        if isLocationAuthorized, let userCoordinates = locationManager.location?.coordinate {
            position = .region(.init(center: userCoordinates, latitudinalMeters: 1000, longitudinalMeters: 1000))
        }
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

    func setProxy(_ mapProxy: MapProxy) {
        self.mapProxy = mapProxy
    }

    func selectMapMode(_ mode: MapLayerMode) {
        isMapSheetPresented = false
        selectedMapItem?.mapSheetFocusedItem = .init()
        mapLayerMode = mode
        fetchDataForCurrentRegion()
    }

    func setMapContext(context: MapCameraUpdateContext) {
        self.region = context.region
        self.rect = context.rect
        self.camera = context.camera
    }

    func showInCircle(_ coordinate: CLLocationCoordinate2D) throws {
        selectMapLocation(coordinate)
    }

    func showInCircle(_ category: Category) throws {
        guard let coordinate = category.coordinate else {
            throw MapError.itemWithoutCoordinateCannotBeShownOnMap
        }
        geoClusterTree.add([.category(category)])
        mapLayerMode = .categoryItems
        selectMapLocation(coordinate, focusedID: category.geoRefID)
    }

    func showInCircle(_ mediaFile: MediaFile) throws {
        guard let coordinate = mediaFile.coordinate else {
            throw MapError.itemWithoutCoordinateCannotBeShownOnMap
        }
        geoClusterTree.add([.media(.init(id: mediaFile.id, coordinate: coordinate, title: mediaFile.bestShortTitle))])
        mapLayerMode = .mediaItem
        selectMapLocation(coordinate, focusedID: mediaFile.id)
    }

    func selectCluster(_ index: H3Index) {
        guard let cluster = clusters[index] else {
            assertionFailure()
            return
        }
        switch mapLayerMode {
        case .categoryItems:
            selectedMapItem = CategoriesInClusterModel(appDatabase: appDatabase, cluster: cluster)
        case .mediaItem:
            selectedMapItem = MediaInClusterModel(appDatabase: appDatabase, cluster: cluster)
        }
        fetchDataForSelectedItem()
        isMapSheetPresented = true
        navigation.clearPath(of: .map)

        guard let currentMapBoxWithSafeArea = region?.paddedBoundingBox(top: -0.25, bottom: -0.3, left: -0.15, right: -0.15) else {
            return
        }

        let isClusterCenterInSafeMapBox = cluster.h3Center.isLocationInBoundingBox(
            topLeft: currentMapBoxWithSafeArea.topLeft,
            bottomRight: currentMapBoxWithSafeArea.bottomRight
        )

        // TODO: only move the camera as much as needed to fit, to minimize screen motion. (-> eg. edge padding (top,bottom,left,right) = clusterradius - (cluster center distance to edge)

        // Zoom/Move camera to location
        if !position.followsUserLocation,
            !isClusterCenterInSafeMapBox,
            let cameraRegion = cluster.cameraRegion(),
            var newCamera = mapProxy?.camera(framing: cameraRegion)
        {
            newCamera.distance = self.camera?.distance ?? newCamera.distance
            newCamera.heading = self.camera?.heading ?? newCamera.heading
            newCamera.pitch = self.camera?.pitch ?? newCamera.pitch
            withAnimation {
                self.position = .camera(newCamera)
            }
        }
    }


    func selectMapLocation(_ coordinate: CLLocationCoordinate2D, focusedID: String? = nil) {
        let radius: CLLocationDistance = 250
        let items = geoClusterTree.items(around: coordinate, radius: radius)

        navigation.clearPath(of: .map)

        switch mapLayerMode {
        case .categoryItems:
            let categoryItems = items.compactMap { $0.category }
            selectedMapItem = CategoriesAroundLocationModel(appDatabase: appDatabase, coordinate: coordinate, radius: radius, categoryItems: categoryItems)
        case .mediaItem:
            let mediaItems = items.compactMap { $0.media }
            selectedMapItem = MediaAroundLocationModel(appDatabase: appDatabase, coordinate: coordinate, radius: radius, mediaItems: mediaItems)
        }

        fetchDataForSelectedItem()
        isMapSheetPresented = true


        let paddingFactor = 0.382
        let delta = GeoVectorMath.degrees(fromMeters: radius * 2, atLatitude: coordinate.latitude)
        let dLat = delta.latitudeDegrees + delta.latitudeDegrees * paddingFactor
        let dLon = delta.longitudeDegrees + delta.longitudeDegrees * paddingFactor
        var offsetCoordinate = coordinate
        offsetCoordinate.latitude -= delta.latitudeDegrees * 0.2
        let newRegion = MKCoordinateRegion(center: offsetCoordinate, span: .init(latitudeDelta: dLat, longitudeDelta: dLon))
        withAnimation {
            self.position = .region(newRegion)
        }
    }

    func resetClusterSelection() {
        isMapSheetPresented = false
        selectedMapItem = nil
    }

    func fetchDataForSelectedItem() {
        Task {
            if let locationItem = selectedMapItem as? MediaAroundLocationModel {
                let newItems: [BasicGeoMediaFile] = await fetchMediaFiles(around: locationItem.coordinate, radius: locationItem.radius)
                    .map(BasicGeoMediaFile.init)
                geoClusterTree.add(newItems.map { .media($0) })
                updateItems()
            } else if let locationItem = selectedMapItem as? CategoriesAroundLocationModel {
                let newItems: [Category] = await fetchWikiItems(around: locationItem.coordinate, radius: locationItem.radius)
                geoClusterTree.add(newItems.map { .category($0) })
                updateItems()
            } else if let clusterItem = selectedMapItem as? MediaInClusterModel {
                let newItems: [BasicGeoMediaFile] = await fetchMediaFiles(around: clusterItem.cluster.h3Center, radius: currentResolution.approxCircleRadius).map { .init(apiItem: $0) }
                geoClusterTree.add(newItems.map { .media($0) })
                updateItems()
            } else if let clusterItem = selectedMapItem as? CategoriesAroundLocationModel {
                let newItems: [Category] = await fetchWikiItems(around: clusterItem.coordinate, radius: currentResolution.approxCircleRadius)
                geoClusterTree.add(newItems.map { .category($0) })
                updateItems()
            }
        }
    }

    func updateItems() {
        updateClusterLayer()
        updateSelectedItem()
    }

    private func updateSelectedItem() {
        guard selectedMapItem != nil else { return }

        if let model = selectedMapItem as? MediaAroundLocationModel {
            let items = geoClusterTree.items(around: model.coordinate, radius: model.radius)
            model.mediaPaginationModel?.replaceIDs(items.compactMap(\.media?.id))
        } else if let model = selectedMapItem as? CategoriesAroundLocationModel {
            let items = geoClusterTree.items(around: model.coordinate, radius: model.radius)
            model.categories = items.compactMap(\.category)
        } else if let model = selectedMapItem as? MediaInClusterModel,
            let updatedCluster = clusters[model.cluster.h3Index]
        {
            model.updateCluster(updatedCluster)
        } else if let model = selectedMapItem as? CategoriesInClusterModel,
            let updatedCluster = clusters[model.cluster.h3Index]
        {
            model.updateCluster(updatedCluster)
        }
    }

    private func updateClusterLayer() {
        guard let region else { return }

        let clock = ContinuousClock()
        let elapsed = clock.measure {
            let boundingBox = region.paddedBoundingBox()
            clusters = geoClusterTree.clusters(
                topLeft: boundingBox.topLeft,
                bottomRight: boundingBox.bottomRight,
                resolution: currentResolution
            )
        }

        //        logger.debug("refreshClusters took \(elapsed)")

        if elapsed > .milliseconds(4) {
            logger.critical("refreshClusters took long! \(elapsed)")
        }
    }

    private func fetchDataForCurrentRegion(shouldDebounce: Bool = true) {
        guard let region else { return }

        fetchTask?.cancel()
        fetchTask = Task {
            if shouldDebounce {
                try await Task.sleep(for: .milliseconds(500))
            }

            currentRefreshingRegion = region
            defer { currentRefreshingRegion = nil }

            logger.info("Map: refreshing started...")

            var items: [GeoItem] = []

            switch mapLayerMode {
            case .categoryItems:
                let wikidataItems = await fetchWikiItems(region: region, maxDiagonalMapLength: wikiItemVisibilityThreshold)
                for wikidataItem in wikidataItems {
                    items.append(.category(wikidataItem))
                }
            case .mediaItem:
                let mediaItems = await fetchMediaFiles(region: region, maxDiagonalMapLength: imageVisibilityThreshold)
                for apiItem in mediaItems {
                    let mediaItem = BasicGeoMediaFile(apiItem: apiItem)
                    items.append(.media(mediaItem))
                }
            }

            geoClusterTree.add(items)
            updateItems()

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

    let bbox = region.paddedBoundingBoxNESW

    do {
        let getAllItems = region.diagonalMeters < 7500

        let items: [Category] = try await API.shared
            .getWikidataItemsInBoundingBox(
                cornerSouthWest: bbox.southWest,
                cornerNorthEast: bbox.northEast,
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

private func fetchWikiItems(around coordinate: CLLocationCoordinate2D, radius: CLLocationDistance) async -> [Category] {

    do {
        let getAllItems = (radius * 2) < 7500

        let items: [Category] = try await API.shared
            .getWikidataItemsAroundCoordinate(
                coordinate,
                kilometerRadius: radius / 1000,
                limit: getAllItems ? 10000 : 200,
                minArea: getAllItems ? nil : 1000,
                languageCode: Locale.current.wikiLanguageCodeIdentifier
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
        let boundingBox = region.paddedBoundingBox()
        assert(boundingBox.bottomRight != boundingBox.topLeft, "bounding box corners must be different")

        let items: [GeoSearchFileItem] = try await API.shared
            .geoSearchFiles(
                topLeft: boundingBox.topLeft,
                bottomRight: boundingBox.bottomRight
            )

        return items
    } catch {
        logger.error("Failed to get files around coordinate \(error), maybe canceled.")
        return []
    }
}

private func fetchMediaFiles(around coordinate: CLLocationCoordinate2D, radius: CLLocationDistance) async -> [GeoSearchFileItem] {
    assert(radius != 0, "Radius should not be 0")
    do {
        let items: [GeoSearchFileItem] = try await API.shared
            .geoSearchFiles(around: coordinate, radius: radius)

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

nonisolated extension BasicGeoMediaFile: GeoReferencable {
    var geoRefID: GeoRefID { self.id }

    var latitude: Double? { coordinate.latitude }
    var longitude: Double? { coordinate.longitude }
}

nonisolated extension Category: GeoReferencable {
    var geoRefID: GeoRefID {
        let geoRefID = wikidataId ?? commonsCategory
        assert(geoRefID != nil)
        return geoRefID!
    }
}
