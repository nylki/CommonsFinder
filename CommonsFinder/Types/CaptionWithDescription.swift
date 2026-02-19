//
//  CaptionWithDescription.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 27.01.26.
//

import Foundation
import os.log

typealias LanguageCode = String
nonisolated struct CaptionWithDescription: Codable, Equatable, Hashable {
    var languageCode: LanguageCode
    var caption: String
    var fullDescription: String
}

nonisolated extension CaptionWithDescription {
    init(languageCode: LanguageCode) {
        self.languageCode = languageCode
        caption = ""
        fullDescription = ""
    }

    init(caption: String = "", fullDescription: String = "", languageCode: LanguageCode) {
        self.caption = caption
        self.fullDescription = fullDescription
        self.languageCode = languageCode
    }
}

/// Allows the set the text for caption and description per languageCode via direct binding
nonisolated extension [CaptionWithDescription] {
    enum FieldType {
        case caption
        case description
    }

    subscript(code: LanguageCode, field: FieldType) -> String {
        get {
            switch field {
            case .caption:
                first(where: { $0.languageCode == code })?.caption ?? ""
            case .description:
                first(where: { $0.languageCode == code })?.fullDescription ?? ""
            }
        }

        set {
            if let idx = firstIndex(where: { $0.languageCode == code }) {
                switch field {
                case .caption: self[idx].caption = newValue
                case .description: self[idx].fullDescription = newValue
                }
            } else {
                logger.warning("unusually setting a description or caption via Binding that didn't exist yet. \(nil)")
                append(.init(caption: newValue, languageCode: code))
            }
        }
    }
}
