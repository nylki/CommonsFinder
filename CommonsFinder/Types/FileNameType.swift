//
//  FileNameType.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 28.12.24.
//


enum FileNameType: String, CaseIterable, CustomStringConvertible {
    /// user enters a file name
    case custom
    case captionOnly
    case captionAndDate
    case geoAndDate

    var description: String {
        switch self {
        case .custom:
            "custom"
        case .captionOnly:
            "caption only"
        case .captionAndDate:
            "caption and date"
        case .geoAndDate:
            "address and date"
        }
    }
}
