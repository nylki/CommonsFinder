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
        if let currentPath = currentPath.last {
            Networking.shared.setReferer("CommonsFinder://\(currentPath.refererPath)")
        } else {
            Networking.shared.setReferer("CommonsFinder://\(selectedTab.refererPath)")
        }
        logger.debug("Referer: \(Networking.shared.referer)")
    }

    //    var isViewingFileSheetOpen: MediaFile.ID?
    var isEditingDraft: DraftSheetNavItem?
    var isAuthSheetOpen: AuthNavigationDestination?

    enum DraftSheetNavItem: Identifiable {
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
        }
    }
}

extension Navigation {
    func clearPath(of tabItem: TabItem) {
        path[tabItem] = []
    }

    func editDrafts(drafts: [MediaFileDraft]) {
        isEditingDraft = .existing(drafts)
    }

    func openNewDraft(options: NewDraftOptions) {
        isEditingDraft = .newDraft(options)
    }

    func openNewDraft() {
        isEditingDraft = .newDraft(nil)
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

    func openOnboarding() {
        isAuthSheetOpen = .onboardingChoice
    }

    func dismissOnboarding() {
        isAuthSheetOpen = nil
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
