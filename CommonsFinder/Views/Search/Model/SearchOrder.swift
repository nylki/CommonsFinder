//
//  SearchOrder.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 02.05.25.
//

import Foundation

enum SearchOrder: Hashable, CaseIterable, CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .relevance: LocalizedStringResource(stringLiteral: "Relevance")
        case .newest: LocalizedStringResource(stringLiteral: "Newest")
        }
    }

    case relevance
    case newest
}
