//
//  PublishingError?+isRetryPossible.swift
//  CommonsFinder
//
//  Created by Tom on 29.07.26.
//

import CommonsAPI
import Foundation

extension MediaFileDraft.PublishingError? {
    var isRetryPossible: Bool {
        switch self {
        case .twoFactorCodeRequired, .emailCodeRequired:
            // TODO: remove these cases, not used with OAuth2
            true
        case .uploadWarnings(let warnings):
            if warnings.contains(.duplicate(name: nil)) || warnings.contains(.duplicateArchive) {
                false
            } else {
                true
            }
        case .appQuitOrCrash:
            true
        case .urlError(_, _):
            true
        case .error(_, _):
            true
        case nil:
            true
        }
    }
}
