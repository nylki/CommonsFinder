//
//  GeoItem.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 20.10.25.
//

import CommonsAPI
import CoreLocation
import Foundation

typealias MediaGeoItem = GeoSearchFileItem
typealias CategoryGeoItem = Category

nonisolated protocol GeoReferencable: Hashable, Equatable {
    typealias GeoRefID = String
    var latitude: Double? { get }
    var longitude: Double? { get }
    var geoRefID: GeoRefID { get }
}

nonisolated extension GeoReferencable {
    var coordinate: CLLocationCoordinate2D? {
        if let latitude, let longitude {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        } else {
            nil
        }
    }
}

nonisolated
    enum GeoItem: GeoReferencable
{
    case media(MediaGeoItem)
    case category(CategoryGeoItem)

    var isMedia: Bool {
        if case .media(_) = self { true } else { false }
    }
    var isCategory: Bool {
        if case .category(_) = self { true } else { false }
    }

    var media: MediaGeoItem? {
        if case .media(let item) = self { item } else { nil }
    }
    var category: CategoryGeoItem? {
        if case .category(let item) = self { item } else { nil }
    }

    var latitude: Double? {
        switch self {
        case .media(let mediaGeoItem):
            mediaGeoItem.latitude
        case .category(let categoryGeoItem):
            categoryGeoItem.latitude
        }
    }

    var longitude: Double? {
        switch self {
        case .media(let mediaGeoItem):
            mediaGeoItem.longitude
        case .category(let categoryGeoItem):
            categoryGeoItem.longitude
        }
    }

    var geoRefID: GeoRefID {
        switch self {
        case .media(let mediaGeoItem):
            mediaGeoItem.geoRefID
        case .category(let categoryGeoItem):
            categoryGeoItem.geoRefID
        }
    }
}
