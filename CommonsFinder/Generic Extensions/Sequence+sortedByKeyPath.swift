//
//  Sequence+sortedByKeyPath.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 12.10.24.
//

import Foundation

nonisolated extension Sequence {
    func sorted(by keyPath: KeyPath<Element, some Comparable>, _ order: ComparisonResult = .orderedAscending) -> [Element] {
        switch order {
        case .orderedAscending:
            sorted { a, b in
                a[keyPath: keyPath] < b[keyPath: keyPath]
            }
        case .orderedDescending:
            sorted { a, b in
                a[keyPath: keyPath] > b[keyPath: keyPath]
            }
        case .orderedSame:
            sorted { a, b in
                a[keyPath: keyPath] == b[keyPath: keyPath]
            }
        }
    }
}
