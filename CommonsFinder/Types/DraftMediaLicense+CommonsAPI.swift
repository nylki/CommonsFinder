//
//  DraftMediaLicense+CommonsAPI.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 04.02.25.
//

import CommonsAPI

extension DraftMediaLicense {
    var wikidataItem: WikidataItemID? {
        switch self {
        case .CC0_1_0: .CC0
        case .CC_BY_4_0: .CC_BY_4_0
        case .CC_BY_SA_4_0: .CC_BY_SA_4_0
        }
    }
}
