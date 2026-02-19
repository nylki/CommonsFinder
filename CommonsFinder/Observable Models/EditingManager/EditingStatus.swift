//
//  EditingStatus.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 06.02.26.
//

import Foundation
import SwiftUI

enum EditingStatus {
    case editing
    case finishedAndPerformingRefresh
    case error(Error)

    var error: Error? {
        switch self {
        case .editing, .finishedAndPerformingRefresh:
            nil
        case .error(let error):
            error
        }
    }
}

extension EditingStatus: CustomStringConvertible, Equatable {
    static func == (lhs: EditingStatus, rhs: EditingStatus) -> Bool {
        lhs.description == rhs.description
    }

    var description: String {
        switch self {
        case .editing: "editing"
        case .finishedAndPerformingRefresh: "finishedAndPerformingRefresh"
        case .error(let error):
            "error-\(error.localizedDescription)"
        }
    }
}
