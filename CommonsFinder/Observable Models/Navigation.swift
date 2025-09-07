//
//  NavigationModel.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 03.10.24.
//

import SwiftUI

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
            print("Nav change: \(path)")
        }
    }

    var currentPath: [NavigationStackItem] {
        path[selectedTab] ?? []
    }


    var selectedTab: TabItem = .home

    //    var isViewingFileSheetOpen: MediaFile.ID?
    var isEditingDraft: DraftSheetNavItem?
    var isAuthSheetOpen: AuthNavigationDestination?

    enum DraftSheetNavItem: Identifiable {
        case newDraft
        case existing([MediaFileDraft])

        var id: String {
            switch self {
            case .newDraft:
                "newDraft"
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
}

extension Navigation {
    func editDrafts(drafts: [MediaFileDraft]) {
        isEditingDraft = .existing(drafts)
    }

    func openNewDraft() {
        isEditingDraft = .newDraft
    }

    func viewFile(mediaFile: MediaFileInfo, namespace: Namespace.ID) {
        path[selectedTab]?.append(.viewFile(mediaFile, namespace: namespace))
    }

    func loadFile(title: String, namespace: Namespace.ID) {
        path[selectedTab]?.append(.loadFile(title: title, namespace: namespace))
    }

    func openOnboarding() {
        isAuthSheetOpen = .onboardingChoice
    }

    func dismissOnboarding() {
        isAuthSheetOpen = nil
    }
}
