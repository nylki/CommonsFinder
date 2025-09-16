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

enum DraftMediaLicense: String, Codable, Hashable, Equatable, CaseIterable {
    //    case CC_PUBLIC_DOMAIN
    case CC0
    case CC_BY
    case CC_BY_SA
}

extension DraftMediaLicense {
    var name: LocalizedStringResource {
        switch self {
        //        case .CC_PUBLIC_DOMAIN:
        //            "Public domain"
        case .CC0:
            "Zero Public Domain, \"No Rights Reserved\""
        case .CC_BY:
            "Attribution"
        case .CC_BY_SA:
            "Attribution-ShareAlike"
        }
    }

    var abbreviation: LocalizedStringResource {
        switch self {
        //        case .CC_PUBLIC_DOMAIN:
        //            "CC Public Domain Mark 1.0"
        case .CC0:
            "CC0"
        case .CC_BY:
            "CC BY"
        case .CC_BY_SA:
            "CC BY-SA"
        }
    }

    var shortDescription: LocalizedStringResource {
        "\(abbreviation): \(name)"
    }

    var wikitext: String {
        switch self {
        //        case .CC_PUBLIC_DOMAIN:
        //            "cc-pd"
        case .CC0:
            "cc0"
        case .CC_BY:
            "cc-by-4.0"
        case .CC_BY_SA:
            "cc-by-sa-4.0"
        }
    }

    var explanation: LocalizedStringResource {
        switch self {
        case .CC0:
            "no rights reserved – public domain or waiver if the PD release is invalidated"
        case .CC_BY:
            "some rights reserved – attribution required"
        case .CC_BY_SA:
            "some rights reserved – attribution and sharing alike required"
        }
    }

}
