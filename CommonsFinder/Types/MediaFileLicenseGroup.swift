//
//  MediaFileLicenseGroup.swift
//  CommonsFinder
//
//  Created by Tom on 24.11.26.
//

import Foundation

nonisolated enum MediaFileLicenseGroup {
    case cc0
    case ccBy
    case ccBySa
    case gfdl  // legacy, multi-license with ccbysa
    case pd
    case GPL
    case FAL  // free art license
    case ODbL  // Open Database License
    case OGL  // Open Government License (eg. https://commons.wikimedia.org/wiki/File:Nadhim_Zahawi_Official_Portrait.jpg)

    var attributionRequired: Bool {
        switch self {
        case .cc0, .pd:
            false
        case .ccBy, .ccBySa, .gfdl, .GPL, .OGL, .ODbL, .FAL:
            true

        }
    }

    var shareAlike: Bool {
        switch self {
        case .ccBySa, .gfdl, .FAL, .GPL, .ODbL:
            true
        case .cc0, .ccBy, .pd, .OGL:
            false

        }
    }

    init?(withWikidataItem wikidataItem: String) {
        let result: Self? =
            switch wikidataItem {
            case "Q6938433":
                .cc0
            case "Q7257361", "Q124175673", "Q98592850":
                .pd
            case "Q6905323", "Q30942811", "Q19125117", "Q18810333", "Q14947546", "Q20007257", "Q26259495":
                .ccBy
            case "Q47001652", "Q19068220", "Q19113751", "Q14946043", "Q18199165", "Q56292840":
                .ccBySa
            case "Q22169", "Q26921685", "Q26921686", "Q26921691", "Q50829096", "Q50829104", "Q27019786":
                .gfdl
            case "Q7603", "Q10513452", "Q10513450", "Q10513445", "Q27016750", "Q27016752", "Q27016754",
                "Q192897", "Q23035974", "Q27016756", "Q18534390", "Q27016757", "Q18534393", "Q27016762":
                .GPL
            case "Q152332", "Q137831636", "Q137831551", "Q124150926":
                .FAL
            case "Q1224853":
                .ODbL
            case "Q17016921", "Q99891660", "Q99891692", "Q99891702":
                .OGL
            default:
                nil
            }

        if let result {
            self = result
        } else {
            return nil
        }
    }

    init?(withLicenseShortname shortname: String) {
        let string = shortname.lowercased().replacing("-", with: " ")

        let result: Self? =
            if string.hasPrefix("cc0") {
                .cc0
            } else if string.hasPrefix("cc by sa") {
                .ccBySa
            } else if string.hasPrefix("cc by") {
                .ccBy
            } else if string.hasPrefix("public domain") || string == "pd" || string.hasPrefix("pd ") {
                .pd
            } else if string.hasPrefix("gfdl") {
                .gfdl
            } else if string.hasPrefix("gpl") || string.hasPrefix("lgpl") {
                .GPL
            } else if string.hasPrefix("fal") || string.hasPrefix("free art") || string.hasPrefix("lal") {
                .FAL
            } else if string.hasPrefix("odbl") {
                .ODbL
            } else if string.hasPrefix("ogl") || string.hasPrefix("open government") {
                .OGL
            } else {
                nil
            }

        if let result {
            self = result
        } else {
            return nil
        }
    }
}
