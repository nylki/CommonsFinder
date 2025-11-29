//
//  SelectedMapItemModel.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 27.10.25.
//


import Algorithms
import GRDB
import MapKit
import SwiftUI
import os.log

@Observable class SelectedMapItemModel: Identifiable {
    let id: String
    var appDatabase: AppDatabase
    var mapSheetFocusedItem: ScrollPosition
    var focusedItemID: String? {
        mapSheetFocusedItem.viewID(type: String.self)
    }
    var humanReadableLocation: String?

    init(appDatabase: AppDatabase, id: String) {
        self.appDatabase = appDatabase
        self.mapSheetFocusedItem = ScrollPosition(idType: GeoReferencable.GeoRefID.self)
        self.id = id
    }
}

protocol ClusterRepresentation: SelectedMapItemModel {
    var cluster: GeoCluster { get }
}

protocol CircleRepresentation: SelectedMapItemModel {
    var radius: CLLocationDistance { get }
    var coordinate: CLLocationCoordinate2D { get }
}

protocol MapItemWithSubItems {
    var focusedIdx: Int? { get }
    var maxCount: Int { get }
}

protocol MapItemWithMedia: SelectedMapItemModel, MapItemWithSubItems {
    var appDatabase: AppDatabase { get }
    var initialMediaItems: [BasicGeoMediaFile] { get }
    var mediaPaginationModel: PaginatableMediaFiles? { get set }
}

protocol MapItemWithCategories: SelectedMapItemModel, MapItemWithSubItems {
    var appDatabase: AppDatabase { get }
    var categories: [Category] { get }
    var resolvedCategories: [CategoryInfo] { get set }
}


@Observable final class MediaAroundLocationModel: SelectedMapItemModel, MapItemWithMedia, CircleRepresentation {
    let coordinate: CLLocationCoordinate2D
    var radius: CLLocationDistance

    internal let initialMediaItems: [BasicGeoMediaFile]
    var mediaPaginationModel: PaginatableMediaFiles?

    init(appDatabase: AppDatabase, coordinate: CLLocationCoordinate2D, radius: CLLocationDistance, mediaItems: [BasicGeoMediaFile]) {
        self.coordinate = coordinate
        self.radius = radius
        self.initialMediaItems = mediaItems
        super.init(appDatabase: appDatabase, id: "\(coordinate.latitude),\(coordinate.longitude)")
        generateHumanReadableLocation()
    }
}

@Observable final class CategoriesAroundLocationModel: SelectedMapItemModel, MapItemWithCategories, CircleRepresentation {
    let coordinate: CLLocationCoordinate2D
    var radius: CLLocationDistance
    var categories: [Category]
    var resolvedCategories: [CategoryInfo] = []

    init(appDatabase: AppDatabase, coordinate: CLLocationCoordinate2D, radius: CLLocationDistance, categoryItems: [Category]) {
        self.coordinate = coordinate
        self.radius = radius
        self.categories = categoryItems
        super.init(appDatabase: appDatabase, id: "\(coordinate.latitude),\(coordinate.longitude)")
        generateHumanReadableLocation()
    }
}


@Observable final class CategoriesInClusterModel: SelectedMapItemModel, MapItemWithCategories, ClusterRepresentation {
    private(set) var cluster: GeoCluster
    var categories: [Category]
    var resolvedCategories: [CategoryInfo] = []

    func updateCluster(_ cluster: GeoCluster) {
        self.categories = cluster.categoryItems
        self.cluster = cluster
    }

    init(appDatabase: AppDatabase, cluster: GeoCluster) {
        self.cluster = cluster
        self.categories = cluster.categoryItems
        super.init(appDatabase: appDatabase, id: "\(cluster.id)")
        generateHumanReadableLocation()
    }
}

@Observable final class MediaInClusterModel: SelectedMapItemModel, MapItemWithMedia, ClusterRepresentation {
    private(set) var initialMediaItems: [BasicGeoMediaFile]
    var mediaPaginationModel: PaginatableMediaFiles?

    private(set) var cluster: GeoCluster

    func updateCluster(_ cluster: GeoCluster) {
        mediaPaginationModel?.replaceIDs(cluster.mediaItems.map(\.id))
        self.cluster = cluster
    }

    init(appDatabase: AppDatabase, cluster: GeoCluster) {
        self.cluster = cluster
        self.initialMediaItems = cluster.mediaItems
        super.init(appDatabase: appDatabase, id: "\(cluster.id)")
        generateHumanReadableLocation()
    }
}

@MainActor
extension MapItemWithMedia {
    var focusedIdx: Int? {
        mediaPaginationModel?.mediaFileInfos.firstIndex(where: { $0.mediaFile.id == focusedItemID })
    }

    var maxCount: Int {
        mediaPaginationModel?.maxCount ?? 0
    }

    func observeAndResolveMediaItems() async {
        guard mediaPaginationModel == nil else { return }
        do {
            mediaPaginationModel = try await .init(appDatabase: appDatabase, initialIDs: initialMediaItems.map(\.id))
            mediaPaginationModel?.paginate()
        } catch {
            logger.error("failed to init mediaPaginationModel \(error)")
        }
    }
}


extension MapItemWithCategories {
    var focusedIdx: Int? {
        resolvedCategories.firstIndex(where: { $0.id == focusedItemID })
    }
    var maxCount: Int {
        resolvedCategories.count
    }

    func observeAndResolveCategories() async {
        do {
            let wikidataIDs = categories.compactMap(\.wikidataId)

            let observation = ValueObservation.tracking { db in
                try CategoryInfo
                    .fetchAll(db, wikidataIDs: wikidataIDs, resolveRedirections: true)
            }
            for try await result in observation.values(in: appDatabase.reader) {
                let fetchedCategories =
                    result
                    .grouped(by: \.base.wikidataId)

                let originalCategories =
                    categories
                    .map { CategoryInfo($0, itemInteraction: nil) }
                    .grouped(by: \.base.wikidataId)

                resolvedCategories = wikidataIDs.compactMap { wikidataID in
                    fetchedCategories[wikidataID]?.first ?? originalCategories[wikidataID]?.first

                }
            }
        } catch {
            logger.error("Failed to observe Category changes in MapPopup \(error)")
        }
    }
}

extension ClusterRepresentation {
    func generateHumanReadableLocation() {
        guard humanReadableLocation == nil else { return }
        Task<Void, Never> {
            do {
                humanReadableLocation = try await cluster.h3Center.generateHumanReadableString(
                    includeCountry: false,
                    includeCity: false
                )
            } catch {
                logger.error("Failed to resolve placemark \(error)")
            }
        }
    }
}

extension CircleRepresentation {
    func generateHumanReadableLocation() {
        guard humanReadableLocation == nil else { return }
        Task<Void, Never> {
            do {
                humanReadableLocation = try await coordinate.generateHumanReadableString(
                    includeCountry: false,
                    includeCity: false
                )
            } catch {
                logger.error("Failed to resolve placemark \(error)")
            }
        }
    }
}

extension SelectedMapItemModel {
    var containsOnlySingleItem: Bool {
        if let model = (self as? MapItemWithSubItems) {
            model.maxCount == 1
        } else {
            false
        }
    }

    var itemCount: Int? {
        if let model = (self as? MapItemWithSubItems) {
            model.maxCount
        } else {
            nil
        }
    }
}
