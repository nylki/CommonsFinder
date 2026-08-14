//
//  PublishingError+localizedDescription.swift
//  CommonsFinder
//
//  Created by Tom on 13.08.26.
//

import Foundation
import SwiftUI

nonisolated
    extension MediaFileDraft.PublishingError: LocalizedError
{
    var errorDescription: String? {
        switch self {
        case .appQuitOrCrash:
            return String(localized: "The app was closed or crashed while uploading.")
        case .uploadWarnings(let warnings):
            return warnings.compactMap { $0 }.first?.localizedDescription ?? "undefined upload warnings"
        case .urlError(let urlErrorCode, let errorDescription):
            let errorCode = URLError.Code(rawValue: urlErrorCode)

            return switch errorCode {
            case .networkConnectionLost: String(localized: "Network connection lost")
            case .badServerResponse: String(localized: "Bad server response")
            case .notConnectedToInternet: String(localized: "not connected To the Internet")
            case .dataLengthExceedsMaximum: String(localized: "Data-length exceeds maximum")
            case .secureConnectionFailed: String(localized: "Secure connection failed")
            case .timedOut: String(localized: "Network Connection timed out")
            case .dnsLookupFailed: String(localized: "DNS Lookup Failed")
            case .userAuthenticationRequired: String(localized: "User authentication required")
            default: debugDescription
            }

        case .error(let errorDescription, _):
            return errorDescription
        case .emailCodeRequired, .twoFactorCodeRequired:
            return String(localized: "Authentication failed: 2-factor code required")
        }
    }
}
