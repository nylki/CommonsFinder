//
//  flatZip.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 27.08.25.
//

import Foundation

/// returns a flat collection of elements that alternates between `a` and `b`
/// eg.:  `zippedFlatMap([1, 2, 3, 4, 5], [8, 9]) = [1, 8, 2, 9, 3, 4, 5]`

func zippedFlatMap<T>(_ a: [T], _ b: [T]) -> [T] {
    var a = ArraySlice(a)
    var b = ArraySlice(b)

    var result: [T] = []
    while !a.isEmpty || !b.isEmpty {
        let poppedA = a.popFirst() ?? b.popFirst()
        let poppedB = b.popFirst() ?? a.popFirst()

        if let poppedA {
            result.append(poppedA)
        }
        if let poppedB {
            result.append(poppedB)
        }

    }
    return result
}
