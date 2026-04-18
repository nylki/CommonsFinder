//
//  RelatedCategoriesType.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 02.04.26.
//


enum RelatedCategoriesType: String, Hashable, CaseIterable, CustomStringConvertible, Identifiable {
    case parent
    case sub

    var description: String {
        switch self {
        case .sub: "Subcategories"
        case .parent: "Parent Categories"
        }
    }

    var id: String { rawValue }
}
