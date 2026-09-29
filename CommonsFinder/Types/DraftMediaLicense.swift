//
//  DraftMediaLicense.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 12.10.24.
//

import SwiftUI

// See: https://commons.wikimedia.org/w/index.php?title=Commons:Licensing

// NOTE: As the name indicates, DraftMediaLicense is scoped only for drafts.
// All licenses that appear on Commons are diverse
// due to several license versions and legacy or edge-cases licenses that are better
// handled separately and a bit differently, see `MediaFileLicense`.

enum DraftMediaLicense: String, Codable, Hashable, Equatable, CaseIterable, RawRepresentable {
    // IMPORTANT: raw values are persisted (DB + UserDefaults).
    /// CC0 1.0
    case CC0_1_0 = "CC0"
    /// CC BY 4.0
    case CC_BY_4_0 = "CC_BY"
    /// CC BY-SA 4.0
    case CC_BY_SA_4_0 = "CC_BY_SA"
    //    case CC_PUBLIC_DOMAIN
}

extension DraftMediaLicense {
    var name: LocalizedStringResource {
        switch self {
        //        case .CC_PUBLIC_DOMAIN:
        //            "Public domain"
        case .CC0_1_0:
            "Zero Public Domain, \"No Rights Reserved\""
        case .CC_BY_4_0:
            "Attribution"
        case .CC_BY_SA_4_0:
            "Attribution-ShareAlike"
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
        case .CC_BY_SA_4_0:
            "CC BY-SA 4.0"
        }
    }

    var shortDescription: LocalizedStringResource {
        "\(abbreviation): \(name)"
    }

    var wikitext: String {
        switch self {
        //        case .CC_PUBLIC_DOMAIN:
        //            "cc-pd"
        case .CC0_1_0:
            "cc0"
        case .CC_BY_4_0:
            "cc-by-4.0"
        case .CC_BY_SA_4_0:
            "cc-by-sa-4.0"
        }
    }

    var explanation: LocalizedStringResource {
        switch self {
        case .CC0_1_0:
            "no rights reserved – public domain or waiver if the PD release is invalidated"
        case .CC_BY_4_0:
            "some rights reserved – attribution required"
        case .CC_BY_SA_4_0:
            "some rights reserved – attribution and sharing alike required"
        }
    }

}
