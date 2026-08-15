//
//  ProcessInfo+isRunnungInPreview.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 26.06.26.
//

import Foundation

extension ProcessInfo {
    static var isRunningInPreview: Bool {
        processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
