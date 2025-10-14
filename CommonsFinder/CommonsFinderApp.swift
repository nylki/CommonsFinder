//
//  CommonsFinderApp.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 24.09.24.
//

import AppIntents
import Nuke
import SwiftUI
import TipKit
import os.log

#if DEBUG
    /// Pulse is included via CommonsAPI package and used here to configure the PulseUI a handy in-app network logger console and
    ///  the (paid) MacOS app. Not bundled when building as Release
    import Pulse
#endif

@main
struct CommonsFinderApp: App {
    private let navigation: Navigation
    private let appDatabase: AppDatabase
    private let searchModel: SearchModel
    private let uploadManager: UploadManager
    private let account: AccountModel

    init() {
        postInstallMaintenance()

        /** _Comment from Apple's AppIntentsSampleApp_:
        
         Register important objects that are required as dependencies of an `AppIntent` or an `EntityQuery`.
         The system automatically sets the value of properties in the intent or entity query to these values when the property is annotated with
         `@Dependency`. Intents that launch the app in the background won't have associated UI scenes, so the app must register these values
         as soon as possible in code paths that don't assume visible UI, such as the `App` initialization.
         */

        let appDatabase = AppDatabase.shared
        self.appDatabase = appDatabase

        let account = AccountModel(appDatabase: appDatabase)
        self.account = account

        let navigation = Navigation()
        self.navigation = navigation

        let searchModel = SearchModel(appDatabase: appDatabase)
        self.searchModel = searchModel

        let uploadManager = UploadManager(appDatabase: appDatabase)
        self.uploadManager = uploadManager


        AppDependencyManager.shared.add(dependency: appDatabase)
        AppDependencyManager.shared.add(dependency: account)
        AppDependencyManager.shared.add(dependency: navigation)
        AppDependencyManager.shared.add(dependency: searchModel)

        /** _Comment from Apple's AppIntentsSampleApp_:
        
         Call `updateAppShortcutParameters` on `AppShortcutsProvider` so that the system updates the App Shortcut phrases with any changes to
         the app's intent parameters. The app needs to call this function during its launch, in addition to any time the parameter values for
         the shortcut phrases change.
         */
        CommonsFinderShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .appDatabase(appDatabase)
                .environment(account)
                .environment(navigation)
                .environment(searchModel)
                .environment(uploadManager)
                .task {
                    postLaunchMaintennce()

                    // Configure and load your TipKit tips at app launch.
                    do {
                        #if DEBUG

                            //                            try Tips.configure()
                            //                            Tips.showAllTipsForTesting()
                        #endif

                        try Tips.configure()

                    } catch {
                        // Handle TipKit errors
                        logger.error("Error initializing TipKit \(error.localizedDescription)")
                    }

                    /// TESTING NOTE: If tests fail in Pulse package, comment out the following block and try again.
                    #if DEBUG
                        RemoteLogger.shared.isAutomaticConnectionEnabled = true
                        ImagePipeline.Configuration.isSignpostLoggingEnabled = true
                        (ImagePipeline.shared.configuration.dataLoader as? DataLoader)?.delegate = URLSessionProxyDelegate()
                    #endif
                    
                    ImageCache.shared.costLimit = 1024 * 1024 * 1000 // 1000 MB
//                    ImageCache.shared.countLimit = 100
                    ImageCache.shared.ttl = 60 * 10 // Invalidate images in memory cache after 10 minutes
                    DataLoader.sharedUrlCache.diskCapacity = 1024 * 1024 * 500 // 500 MB
                    DataLoader.sharedUrlCache.memoryCapacity = 0
                }
        }

    }

    private func postLaunchMaintennce() {
        do {
            try account.cleanupOldDrafts()
        } catch {
            logger.error("Failed postLaunchMaintennce cleanupOldDrafts! \(error)")
        }
    }
}

private func postInstallMaintenance() {
    // Perform post install maintanence

    let hasKeychainBeenCleared = UserDefaults.standard.bool(forKey: "postInstallKeychainCleared")

    if hasKeychainBeenCleared == false {
        // NOTE: keychain will items persist across app un-installs and re-installs!
        // This is undocumented but well known for may years:
        // see: https://developer.apple.com/forums/thread/36442
        // and: https://forums.developer.apple.com/forums/thread/22874?answerId=75464022#75464022

        // Current handling: remove keys on first launch.
        // alternative handling (1): encrypt items with unique key so the items cannot be accessed (more maintenance, but more secure)
        // alternative handling (2): Persisted username/password is accepted -> faster login for user
        // but may complicate things a bit if not intended by user or password was already changed or something...
        do {
            try Authentication.clearKeychain()
        } catch {
            assertionFailure("Failed to clear keychain of first launch!")
        }

        UserDefaults.standard.set(true, forKey: "postInstallKeychainCleared")
    }
}
