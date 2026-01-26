//
//  UserDefaults+accessors.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 20.01.26.
//

import Foundation

extension UserDefaults {
    var defaultPublishingLicense: DraftMediaLicense? {
        if let rawValue = string(forKey: "defaultPublishingLicense") {
            DraftMediaLicense(rawValue: rawValue)
        } else {
            nil
        }
    }
}
