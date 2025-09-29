//
//  CGSize+magnitude.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 25.09.25.
//

import Accelerate
import Foundation

extension CGSize {
    func magnitude() -> Double {
        vDSP.meanMagnitude([width, height])
    }
}

extension CGSize {
    var aspectRatio: Double {
        height / width
    }

    static func + (lhs: Self, rhs: Self) -> Self {
        .init(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }

    static func - (lhs: Self, rhs: Self) -> Self {
        .init(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
    }

    static func += (lhs: inout Self, rhs: Self) {
        lhs = lhs + rhs
    }

    func scaled(by factor: CGFloat) -> CGSize {
        .init(width: width * factor, height: height * factor)
    }
}
