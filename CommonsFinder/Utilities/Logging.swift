//
//  Logging.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 14.11.24.
//


import Foundation
import os.log

nonisolated let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "generic")

// inspiration: https://www.avanderlee.com/debugging/oslog-unified-logging/
//extension Logger {
//    /// Using your bundle identifier is a great way to ensure a unique identifier.
//    private static var subsystem = Bundle.main.bundleIdentifier!
//
//    /// Logs the view cycles like a view that appeared.
//    static let viewCycle = Logger(subsystem: subsystem, category: "viewcycle")
//
//    /// All logs related to tracking and analytics.
//    static let statistics = Logger(subsystem: subsystem, category: "statistics")
//}
