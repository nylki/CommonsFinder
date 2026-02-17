//
//  EditingError.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 06.02.26.
//
import Foundation

enum EditingError: LocalizedError {
    case authenticationRequired

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            "Please sign in to your Wikimedia account again before publishing changes."
        }
    }
}
