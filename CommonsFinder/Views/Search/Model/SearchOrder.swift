//
//  SearchOrder.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 02.05.25.
//

import Foundation

nonisolated enum SearchOrder: String, Hashable, Equatable, CaseIterable, CustomLocalizedStringResourceConvertible, Sendable {
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .relevance: LocalizedStringResource(stringLiteral: "Relevant")
        case .newest: LocalizedStringResource(stringLiteral: "Newest")
        case .oldest: LocalizedStringResource(stringLiteral: "Oldest")
        }
    }

    case relevance
    case newest
    case oldest
}
