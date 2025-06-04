//
//  Shortcuts.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 31.10.24.
//

import AppIntents
import Foundation

class shortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: InAppSearchIntent(),
            phrases: [
                "Search in \(.applicationName)"
            ],
            shortTitle: "In-App Search",
            systemImageName: "magnifyingglass"
        )
    }
}
