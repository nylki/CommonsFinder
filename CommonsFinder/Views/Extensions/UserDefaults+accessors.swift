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

    var additionalInputLanguages: [Locale.LanguageCode] {
        get {
            if let rawValue = string(forKey: "additionalInputLanguages") {
                [Locale.LanguageCode](rawValue: rawValue) ?? []
            } else {
                []
            }
        }
        set {
            set(newValue.rawValue, forKey: "additionalInputLanguages")
        }
    }
}
