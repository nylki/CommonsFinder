//
//  DraftMediaLicense.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 12.10.24.
//

import SwiftUI

// See: https://commons.wikimedia.org/w/index.php?title=Commons:Licensing#Acceptable licenses

// NOTE: As the name indicates, DraftMediaLicense is scoped only for drafts.
// All licenses that appear on Commons are diverse
// due to several license versions and legacy or edge-cases licenses that are better
// handled separately and a bit differently, see `MediaFileLicense`.


nonisolated enum DraftMediaLicense: Codable, Hashable, Equatable, RawRepresentable {
    // IMPORTANT: raw values are persisted (DB + UserDefaults).
    case CC0_1_0
    case CC_BY_4_0
    case CC_BY_3_0
    case CC_BY_2_5
    case CC_BY_SA_4_0
    case CC_BY_SA_3_0
    case CC_BY_SA_2_5
    //    case CC_PUBLIC_DOMAIN

    // TODO: check if wikitext is an accepted license
    case custom(wikitext: String)

    static let publishingChoices: [DraftMediaLicense] = [.CC0_1_0, .CC_BY_4_0, .CC_BY_SA_4_0]

    static let originalChoices: [DraftMediaLicense] = [
        .CC0_1_0, .CC_BY_4_0, .CC_BY_3_0, .CC_BY_2_5, .CC_BY_SA_4_0, .CC_BY_SA_3_0, .CC_BY_SA_2_5,
    ]

    init?(rawValue: String) {
        switch rawValue {
        case "CC0": self = .CC0_1_0
        case "CC_BY": self = .CC_BY_4_0
        case "CC_BY_3_0": self = .CC_BY_3_0
        case "CC_BY_2_5": self = .CC_BY_2_5
        case "CC_BY_SA": self = .CC_BY_SA_4_0
        case "CC_BY_SA_3_0": self = .CC_BY_SA_3_0
        case "CC_BY_SA_2_5": self = .CC_BY_SA_2_5
        default:
            guard !rawValue.isEmpty else { return nil }
            self = .custom(wikitext: rawValue)
        }
    }

    var rawValue: String {
        switch self {
        case .CC0_1_0: "CC0"
        case .CC_BY_4_0: "CC_BY"
        case .CC_BY_3_0: "CC_BY_3_0"
        case .CC_BY_2_5: "CC_BY_2_5"
        case .CC_BY_SA_4_0: "CC_BY_SA"
        case .CC_BY_SA_3_0: "CC_BY_SA_3_0"
        case .CC_BY_SA_2_5: "CC_BY_SA_2_5"
        case .custom(let wikitext): wikitext
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let license = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown DraftMediaLicense raw value: \(rawValue)")
        }
        self = license
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated
    extension DraftMediaLicense
{
    var name: LocalizedStringResource {
        switch self {
        //        case .CC_PUBLIC_DOMAIN:
        //            "Public domain"
        case .CC0_1_0:
            "Zero Public Domain, \"No Rights Reserved\""
        case .CC_BY_4_0, .CC_BY_3_0, .CC_BY_2_5:
            "Attribution"
        case .CC_BY_SA_4_0, .CC_BY_SA_3_0, .CC_BY_SA_2_5:
            "Attribution-ShareAlike"
        case .custom:
            "Other license"
        }
    }

    var abbreviation: LocalizedStringResource {
        switch self {
        //        case .CC_PUBLIC_DOMAIN:
        //            "CC Public Domain Mark 1.0"
        case .CC0_1_0:
            "CC0 1.0"
        case .CC_BY_4_0:
            "CC BY 4.0"
        case .CC_BY_3_0:
            "CC BY 3.0"
        case .CC_BY_2_5:
            "CC BY 2.5"
        case .CC_BY_SA_4_0:
            "CC BY-SA 4.0"
        case .CC_BY_SA_3_0:
            "CC BY-SA 3.0"
        case .CC_BY_SA_2_5:
            "CC BY-SA 2.5"
        case .custom(let wikitext):
            "\(wikitext)"
        }
    }

    var shortDescription: LocalizedStringResource {
        "\(abbreviation): \(name)"
    }

    var isCustom: Bool {
        if case .custom = self { true } else { false }
    }

    var customWikitext: String? {
        switch self {
        case .custom(let wikitext): wikitext
        default: nil
        }
    }

    var wikitext: String {
        switch self {
        //        case .CC_PUBLIC_DOMAIN:
        //            "cc-pd"
        case .CC0_1_0:
            "cc0"
        case .CC_BY_4_0:
            "cc-by-4.0"
        case .CC_BY_3_0:
            "cc-by-3.0"
        case .CC_BY_2_5:
            "cc-by-2.5"
        case .CC_BY_SA_4_0:
            "cc-by-sa-4.0"
        case .CC_BY_SA_3_0:
            "cc-by-sa-3.0"
        case .CC_BY_SA_2_5:
            "cc-by-sa-2.5"
        case .custom(let wikitext):
            wikitext.trimmingCharacters(in: .init(arrayLiteral: "{", "}", "|"))
        }
    }

    var explanation: LocalizedStringResource? {
        switch self {
        case .CC0_1_0:
            "no rights reserved – public domain or waiver if the PD release is invalidated"
        case .CC_BY_4_0, .CC_BY_3_0, .CC_BY_2_5:
            "some rights reserved – attribution required"
        case .CC_BY_SA_4_0, .CC_BY_SA_3_0, .CC_BY_SA_2_5:
            "some rights reserved – attribution and sharing alike required"
        case .custom:
            nil
        }
    }

}
