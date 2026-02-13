//
//  ContentView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 24.09.24.
//

import NukeUI
import SwiftUI
import WidgetKit
import os.log

struct ContentView: View {
    @Environment(Navigation.self) private var navigation
    @Environment(SearchModel.self) private var searchModel
    @Environment(AccountModel.self) private var accountModel
    @Environment(UploadManager.self) private var uploadManager
    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {

        @Bindable var navigation = navigation
        let tabBinding = Binding<Navigation.TabItem>(
            get: { navigation.selectedTab },
            set: { tab in
                if navigation.selectedTab == tab {
                    subsequentTap(on: tab)
                }
                navigation.selectedTab = tab
            }
        )

        TabView(selection: tabBinding) {
            Tab("Home", systemImage: "house", value: Navigation.TabItem.home) {
                NavigationStack(path: $navigation.homePath) {
                    HomeView()
                        .modifier(CommonNavigationDestination())
                }
            }
            Tab("Map", systemImage: "map", value: Navigation.TabItem.map) {
                NavigationStack(path: $navigation.mapPath) {
                    MapView()
                        .modifier(CommonNavigationDestination())
                }
            }

            //            Tab("Events", systemImage: "figure.socialdance", value: Navigation.TabItem.events) {
            //                NavigationStack(path: $navigation.eventsPath) {
            //                    Text("Current and nearby events")
            //                        .modifier(CommonNavigationDestination())
            //                }
            //            }

            Tab(value: Navigation.TabItem.search, role: .search) {
                NavigationStack(path: $navigation.searchPath) {
                    SearchView()
                        .modifier(CommonNavigationDestination())
                }

            }
        }
        .sheet(item: $navigation.isAuthSheetOpen, content: AuthView.init)
        //        .sheet(item: $navigation.isEditingDraft) { destination in
        //            switch destination {
        //            case .existing(let files):
        //                FileCreateView(appDatabase: appDatabase, files: files)
        //            case .newDraft(let options):
        //                FileCreateView(appDatabase: appDatabase, newDraftOptions: options)
        //            }
        //        }
        .modifier(DraftSheetModifer(model: $navigation.isEditingDraft))
        .onOpenURL(perform: handleURL)
        .onContinueUserActivity(NSUserActivityTypeLiveActivity) { userActivity in
            guard let url = userActivity.webpageURL else { return }
            handleURL(url)
        }
        .onChange(of: scenePhase, initial: true) { oldValue, newValue in
            if newValue == .active, accountModel.activeUser != nil {
                accountModel.syncUserData()
            }
        }
    }

    private func subsequentTap(on tab: Navigation.TabItem) {
        switch tab {
        case .home: break
        case .map: break
        case .events: break
        case .search: searchModel.focusSearchField()
        }
        logger.info("Subsequent taps on tab \(tab.rawValue)")
    }

    private func handleURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
            let shareExtensionContainerURL = URL.shareExtensionContainerURL
        else {
            return
        }

        switch (url.scheme, components.host) {
        // -> "CommonsFinder://ShareExtension"
        case ("CommonsFinder", "ShareExtension"):
            // TODO: this could be implemented with an intent handler instead in iOS 26 maybe?
            // -> "CommonsFinder://ShareExtension/openDrafts"
            guard url.pathComponents.count == 2, url.pathComponents[1] == "openDrafts" else {
                assertionFailure()
                return
            }
            let urls: [URL]?
            urls = components.queryItems?
                .filter { $0.name == "draft" }
                .compactMap {
                    if let filename = $0.value {
                        shareExtensionContainerURL.appending(component: filename)
                    } else {
                        nil
                    }
                }


            guard let urls, !urls.isEmpty else {
                assertionFailure("We expect a list of file urls from the share extension. It must not be empty!")
                return
            }

            logger.info("Received drafts from share extension \(urls)")
            let drafts: [MediaFileDraft] = urls.compactMap { temporaryPath in
                do {
                    let fileItem = try FileItem(movingLocalFileFromPath: temporaryPath)
                    let draft = try MediaFileDraft(fileItem)
                    return try appDatabase.upsertAndFetch(draft)
                } catch {
                    logger.error("Failed to move draft file from ShareExtension. \(error)")
                    assertionFailure()
                    return nil
                }
            }

            Task {
                // A short visually delay to allow the opening app animations to settle a moment
                try? await Task.sleep(for: .milliseconds(200))
                if drafts.count > 1 {
                    // TODO: needs batch image implementation
                    navigation.selectedTab = .home
                } else {
                    navigation.editDrafts(drafts: drafts)
                }
            }

        default:
            logger.warning(
                """
                    "Tried to open unknown URL-scheme or action. 
                    \(url.scheme ?? "") \(components.host ?? "")
                """)
        }
    }
}

struct CommonNavigationDestination: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: NavigationStackItem.self) { item in
                switch item {
                case .settings: SettingsView()
                case .viewFile(let file, let namespace):
                    FileDetailView(file, namespace: namespace)
                //                    FileDetailView(mediaFileInfo: file, navigationNamespace: namespace)
                case .loadFile(let title, let namespace):
                    FileLoadView(title: title, navigationNamespace: namespace)
                case .wikidataItem(let item):
                    CategoryView(item)
                case .userUploads(let username):
                    UploadsView(username: username)
                case .recentlyViewedMedia:
                    RecentlyViewedMediaView()
                case .bookmarkedMedia:
                    BookmarkedFilesView()
                case .bookmarkedCategories:
                    BookmarkedCategoriesView()
                case .recentlyViewedCategories:
                    RecentlyViewedCategoriesView()
                }
            }
    }
}


#Preview(traits: .previewEnvironment) {
    ContentView()
}
