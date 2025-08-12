//
//  AppDatabase+SwiftUI.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 04.10.24.
//

import GRDB
import GRDBQuery
import SwiftUI
import os.log

// MARK: - Give SwiftUI access to the AppDatabase

// Define a new environment key that grants access to a `AppDatabase`.
// The technique is documented at
// <https://developer.apple.com/documentation/swiftui/environmentvalues/>.
extension EnvironmentValues {
    @Entry var appDatabase: AppDatabase = .empty()
}

extension View {
    /// Sets both the `database` (for writes) and `databaseContext`
    /// (for `@Query`) environment values.
    ///
    func appDatabase(_ repository: AppDatabase) -> some View {
        self
            .environment(\.appDatabase, repository)
            .databaseContext(.readOnly { repository.reader })
    }
}
