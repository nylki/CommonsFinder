import AsyncAlgorithms
import CommonsAPI
import CoreLocation
import H3kit
import MapKit
import Nuke
import OrderedCollections
//
//  MapModel.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 28.02.25.
//
import SwiftUI
import os.log

enum GeoItem: GeoReferencable, Identifiable {
    case mediaFile(GeosearchListItem)
    case wikidataItem(Category)  // FIXME: use CategoryInfo!?

    var id: String {
        switch self {
        case .mediaFile(let geosearchListItem):
            "\(geosearchListItem.id)"
        case .wikidataItem(let wikidataItem):
            "\(wikidataItem.wikidataId ?? String(wikidataItem.hashValue))"
        }
    }

    var latitude: Double? {
        switch self {
        case .mediaFile(let geosearchListItem):
            geosearchListItem.lat
        case .wikidataItem(let wikidataItem):
            wikidataItem.location?.latitude
        }
    }

    var longitude: Double? {
        switch self {
        case .mediaFile(let geosearchListItem):
            geosearchListItem.lon
        case .wikidataItem(let wikidataItem):
            wikidataItem.location?.longitude
        }
    }

    var isWikidataItem: Bool {
        if case .wikidataItem = self { true } else { false }
    }

    var isMediaFile: Bool {
        if case .mediaFile = self { true } else { false }
    }

    var mediaFileItem: GeosearchListItem? {
        switch self {
        case .mediaFile(let geosearchListItem):
            geosearchListItem
        default: nil
        }
    }

    var wikidataItem: Category? {
        switch self {
        case .wikidataItem(let wikidataItem):
            wikidataItem
        default: nil
        }
    }
}

@Observable @MainActor final class MapModel {
    var position: MapCameraPosition = .automatic
    var locale: Locale = .current

    private(set) var region: MKCoordinateRegion?

    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?

    private var refreshRegionChannel: AsyncChannel<MKCoordinateRegion> = .init()
    private(set) var lastRefreshedRegions: OrderedSet<MKCoordinateRegion> = .init()
    private(set) var currentRefreshingRegion: MKCoordinateRegion?
    var isRefreshingMap: Bool { currentRefreshingRegion != nil }

    // FIXME: constantly filling the cluster collections may end up eating all memory
    // we need to prune them when they get too big, based to distance to current region
    @ObservationIgnored
    private(set) var mediaClustering: GeoClustering<GeosearchListItem> = .init()
    @ObservationIgnored
    private(set) var wikiItemClustering: GeoClustering<CategoryInfo> = .init()

    private(set) var clusters:
        [UInt64: (
            mediaItems: [GeosearchListItem],
            wikiItems: [CategoryInfo]
        )] = .init()

    private(set) var selectedCluster: H3Index?


    var isSheetPresented = false
    /// The item that is scrolled to inside the sheet when tapping on a cluster circle
    var focusedClusterItem = ScrollPosition(idType: String.self)


    @ObservationIgnored
    private var locationTrackTrack: Task<Void, Never>?

    private var locationManager: CLLocationManager = .init()

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

    func setRegion(region: MKCoordinateRegion) {
        self.region = region
    }

    func selectCluster(_ index: H3Index) {
        focusedClusterItem = .init()
        selectedCluster = index
        isSheetPresented = true
        // TODO: fetch items in circle radius if items > max (500?)
    }

    func refreshClusters() {
        guard let region else { return }

        let clock = ContinuousClock()
        let elapsed = clock.measure {


            var mediaClusters: [UInt64: [GeosearchListItem]] = .init()
            var wikiItemClusters: [UInt64: [CategoryInfo]] = .init()

            if region.diagonalMeters < imageVisibilityThreshold {
                mediaClusters = mediaClustering.clusters(
                    topLeft: region.boundingBox.topLeft,
                    bottomRight: region.boundingBox.bottomRight,
                    resolution: currentResolution
                )
            }

            if region.diagonalMeters < wikiItemVisibilityThreshold {
                wikiItemClusters = wikiItemClustering.clusters(
                    topLeft: region.boundingBox.topLeft,
                    bottomRight: region.boundingBox.bottomRight,
                    resolution: currentResolution
                )
            }

            let clusterIndices = Set(mediaClusters.keys).union(wikiItemClusters.keys)
            var clusterDict = [
                UInt64: (
                    mediaItems: [GeosearchListItem],
                    wikiItems: [CategoryInfo]
                )
            ]()

            for index in clusterIndices {
                clusterDict[index] = (
                    mediaClusters[index] ?? [],
                    wikiItemClusters[index] ?? []
                )
            }

            clusters = clusterDict
        }

        //        logger.debug("refreshClusters took \(elapsed)")

        if elapsed > .milliseconds(4) {
            logger.critical("refreshClusters took long! \(elapsed)")
        }

    }

    init() {
        guard refreshTask == nil else { return }

        refreshTask = Task<Void, Never> {
            // TODO: optimize by remember regions that have been fully fetched (not hitting item limits)
            // and then comparing if current region is significant not only against last region
            // but ALL the regions..

            // TODO: test actively tracking positions if the debounce every yields a refresh eg. when walking and user positions
            for await region in refreshRegionChannel.debounce(for: .milliseconds(500), tolerance: .milliseconds(20)) {
                currentRefreshingRegion = region
                defer { currentRefreshingRegion = nil }

                logger.info("Map: refreshing started...")

                async let wikiItemsTask = fetchWikiItems(region: region, maxDiagonalMapLength: wikiItemVisibilityThreshold)
                async let mediaTask = fetchMediaFiles(region: region, maxDiagonalMapLength: imageVisibilityThreshold)
                let (wikidataItems, mediaItems) = await (wikiItemsTask, mediaTask)

                let wikidataItemInfo: [CategoryInfo] = wikidataItems.map {
                    .init($0)
                }
                wikiItemClustering.add(wikidataItemInfo)
                mediaClustering.add(mediaItems)
                refreshClusters()

                lastRefreshedRegions.append(region)
                logger.info("Map: refreshing finished.")
            }
        }
    }

    //    func stopCurrentLocationUpdates() {
    //        liveTask?.cancel()
    //        liveTask = nil
    //    }

    /// Continuously tracks and follows tne position on the map (i.e. Navigation mode)
    func followUserPosition() {
        locationManager.activityType = .otherNavigation
        locationManager.distanceFilter = 7
        locationManager.requestWhenInUseAuthorization()
        position = .userLocation(followsHeading: true, fallback: .automatic)
    }

    /// sets the user location once
    func locateUserPosition() {
        locationTrackTrack?.cancel()
        locationTrackTrack = Task<Void, Never> {
            do {
                for try await locationUpdate in CLLocationUpdate.liveUpdates(.otherNavigation) {
                    try Task.checkCancellation()
                    guard let location = locationUpdate.location else { continue }

                    position = .camera(.init(centerCoordinate: location.coordinate, distance: 1000))
                    // Here we are only interested in a single location update
                    // thus break out of the loop and save battery.
                    //                    break
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

        Task<Void, Never> {
            await refreshRegionChannel.send(context.region)
        }
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

private func fetchMediaFiles(region: MKCoordinateRegion, maxDiagonalMapLength: Double) async -> [GeosearchListItem] {
    guard region.diagonalMeters < maxDiagonalMapLength else { return [] }
    do {
        let boundingBox = region.boundingBox

        let items: [GeosearchListItem] = try await API.shared
            .geoSearchFiles(
                topLeft: boundingBox.topLeft,
                bottomRight: boundingBox.bottomRight
            )


        guard !items.isEmpty else {
            return []
        }

        print("fetched files: \(items.count)")
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

extension GeosearchListItem: GeoReferencable {
    var latitude: Double? { lat }
    var longitude: Double? { lon }
}

extension CategoryInfo: GeoReferencable {
    var latitude: Double? { base.latitude }
    var longitude: Double? { base.longitude }
}
