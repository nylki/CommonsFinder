//
//  Array+popFirstN.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 26.08.25.
//


import Algorithms
import Foundation

extension Array {
    /// returns the first n-items or less if the Collection is smaller and removes those items at the same time from the Collection.
    @inlinable public mutating func popFirst(n: Int) -> Self {
        guard n > 0 else { return [] }
        let n = Swift.min(n, count)
        let popResult = prefix(n)
        removeFirst(n)
        return Array(popResult)
    }
}
