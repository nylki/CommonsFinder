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
        case .CC0: .Q(6_938_433)
        case .CC_BY: .Q(6_905_323)
        case .CC_BY_SA: .Q(18_199_165)
        }
    }
}
