//
//  CGPoin+Extensions.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 25.09.25.
//

import Foundation

extension CGPoint {
    static func + (lhs: Self, rhs: Self) -> Self {
        .init(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func += (lhs: inout Self, rhs: Self) {
        lhs = lhs + rhs
    }
}
