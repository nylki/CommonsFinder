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
        case .CC0_1_0: .Q(6_938_433)
        case .CC_BY_4_0: .Q(6_905_323)
        case .CC_BY_SA_4_0: .Q(18_199_165)
        }
    }
}
