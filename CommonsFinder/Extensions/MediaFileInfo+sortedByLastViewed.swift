//
//  MediaFileInfo+sorted.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 21.05.25.
//

import Foundation

extension [MediaFileInfo] {
    func sortedByLastViewed(using comparator: ComparisonResult) -> Self {
        sorted(by: { a, b in
            guard let lastViewedA = a.lastViewed,
                let lastViewedB = b.lastViewed
            else {
                return false
            }

            return switch comparator {
            case .orderedAscending:
                lastViewedA < lastViewedB
            case .orderedSame:
                lastViewedA == lastViewedB
            case .orderedDescending:
                lastViewedA > lastViewedB
            }
        })
    }

}
