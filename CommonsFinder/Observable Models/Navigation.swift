//
//  NavigationModel.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 03.10.24.
//

import CoreLocation
import SwiftUI
import os.log

@Observable final class Navigation {
    var homePath: [NavigationStackItem] {
        get {
            path[.home] ?? []
        }
        set {
            path[.home] = newValue
        }
    }

    var mapPath: [NavigationStackItem] {
        get {
            path[.map] ?? []
        }
        set {
            path[.map] = newValue
        }
    }

    var eventsPath: [NavigationStackItem] {
        get {
            path[.events] ?? []
        }
        set {
            path[.events] = newValue
        }
    }

    var searchPath: [NavigationStackItem] {
        get {
            path[.search] ?? []
        }
        set {
            path[.search] = newValue
        }
    }

    private var path: [TabItem: [NavigationStackItem]] = [.home: [], .map: [], .events: [], .search: []] {
        didSet {
            updateReferer()
        }
    }

    var currentPath: [NavigationStackItem] {
        path[selectedTab] ?? []
    }


    var selectedTab: TabItem = .home {
        didSet {
            updateReferer()
        }
    }

    private func updateReferer() {
        Task {
            if let currentPath = currentPath.last {
                await Networking.shared.setReferer("commonsfinder://\(currentPath.refererPath)")
            } else {
                await Networking.shared.setReferer("commonsfinder://\(selectedTab.refererPath)")
            }
        }
    }

    //    var isViewingFileSheetOpen: MediaFile.ID?
    var isImportingFiles: FileImportModel?
    var isEditingDraft: MediaFileDraftModel?
    var isEditingMultipleDrafts: [MediaFileDraftModel]?

    enum DraftSheetNavItem: Identifiable, Equatable {
        case newDraft(NewDraftOptions?)
        case existing([MediaFileDraft])

        var id: String {
            switch self {
            case .newDraft(let options):
                "newDraft-\(options.hashValue)"
            case .existing(let drafts):
                "existing-\(drafts.hashValue)"
            }
        }
    }

    enum TabItem: String, Hashable {
        case home
        case map
        case events
        case search

        var refererPath: String {
            switch self {
            case .home:
                "Home"
            case .map:
                "Map"
            case .events:
                "Events"
            case .search:
                "Search"
            }
        }
    }
}

enum NavigationStackItem: Hashable, CustomStringConvertible {
    case settings
    case viewFile(MediaFileInfo, namespace: Namespace.ID)
    case loadFile(title: String, namespace: Namespace.ID)
    case wikidataItem(_ item: CategoryInfo)
    case userUploads(username: String)
    case recentlyViewedMedia
    case bookmarkedMedia
    case recentlyViewedCategories
    case bookmarkedCategories
    case relatedCategories(_ item: CategoryInfo, _ type: RelatedCategoriesType)

    var description: String {
        switch self {
        case .settings:
            "settings"
        case .viewFile(let mediaFileInfo, let namespace):
            "viewFile-\(mediaFileInfo.id)-namespace-\(namespace.hashValue)"
        case .loadFile(let title, let namespace):
            "loadFile-\(title)-namespace-\(namespace.hashValue)"
        case .wikidataItem(let item):
            "tag-\(item.id)"
        case .userUploads(let username):
            "userUploads-\(username)"
        case .recentlyViewedMedia:
            "recentlyViewedMedia"
        case .bookmarkedMedia:
            "bookmarkedMedia"
        case .recentlyViewedCategories:
            "recentlyViewedCategories"
        case .bookmarkedCategories:
            "bookmarkedCategories"
        case .relatedCategories(let item, let type):
            "relatedCategories-\(item.id)-\(type.description)"
        }
    }

    var refererPath: String {
        switch self {
        case .settings: ""
        case .viewFile(let mediaFileInfo, _):
            "File:\(mediaFileInfo.mediaFile.name)"
        case .loadFile(let title, _):
            "File:\(title)"
        case .wikidataItem(let item):
            "Wikidata:\(item.id)"
        case .userUploads(let username):
            "User:\(username)"
        case .recentlyViewedMedia, .bookmarkedMedia, .recentlyViewedCategories, .bookmarkedCategories:
            ""
        case .relatedCategories(let item, let type):
            if let commonsCategory = item.base.commonsCategory {
                "Category:\(commonsCategory)"
            } else {
                "Wikidata:\(item.id)"
            }
        }
    }
}

extension Navigation {
    func clearPath(of tabItem: TabItem) {
        path[tabItem] = []
    }

    func editDraft(draft: MediaFileDraft) {
        isEditingDraft = .init(existingDraft: draft)
    }

    func editMultipleDrafts(drafts: [MediaFileDraft]) {
        isEditingMultipleDrafts = drafts.map { .init(existingDraft: $0) }
    }

    func openNewDraft(options: NewDraftOptions) {
        isImportingFiles = .init(newDraftOptions: options)
    }

    func openNewDraft() {
        isImportingFiles = .init(newDraftOptions: nil)
    }

    func viewFile(mediaFile: MediaFileInfo, namespace: Namespace.ID) {
        path[selectedTab]?.append(.viewFile(mediaFile, namespace: namespace))
    }

    func loadFile(title: String, namespace: Namespace.ID) {
        path[selectedTab]?.append(.loadFile(title: title, namespace: namespace))
    }

    func viewCategory(_ categoryInfo: CategoryInfo) {
        path[selectedTab]?.append(.wikidataItem(categoryInfo))
    }

    func viewRelatedCategories(of categoryInfo: CategoryInfo, type: RelatedCategoriesType) {
        path[selectedTab]?.append(.relatedCategories(categoryInfo, type))
    }

    func showOnMap(category: Category, mapModel: MapModel) {
        do {
            try mapModel.showInCircle(category)
            selectedTab = .map
        } catch {
            logger.error("Failed to show category on map \(error)")
        }
    }

    func showOnMap(mediaFile: MediaFile, mapModel: MapModel) {
        do {
            try mapModel.showInCircle(mediaFile)
            selectedTab = .map
        } catch {
            logger.error("Failed to show mediafile on map \(error)")
        }
    }

    func showOnMap(coordinate: CLLocationCoordinate2D, mapModel: MapModel) {
        do {
            try mapModel.showInCircle(coordinate)
            selectedTab = .map
        } catch {
            logger.error("Failed to show coordinates on map \(error)")
        }
    }
}
