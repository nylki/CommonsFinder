//
//  NavigationModel.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 03.10.24.
//

import SwiftUI

@MainActor
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
    /// category title without the prefix
    case category(title: String)
    case wikiItem(id: String)
    case tag(TagItem)
    case userUploads(username: String)
    case recentlyViewed

    var description: String {
        switch self {
        case .settings:
            "settings"
        case .loadFile(let title, let namespace):
            "loadFile-\(title)-namespace-\(namespace.hashValue)"
        case .viewFile(let file, let namespace):
            "viewFile-\(file.id)-namespace-\(namespace.hashValue)"
        case .tag(let tagItem):
            "tag-\(tagItem.id)"
        case .category(let title):
            "category-\(title)"
        case .wikiItem(let id):
            "wikiItem-\(id)"
        case .userUploads(let username):
            "userUploads-\(username)"
        case .recentlyViewed:
            "recentlyViewed"
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
