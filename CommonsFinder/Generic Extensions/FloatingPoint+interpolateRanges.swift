//
//  FloatingPoint+interpolateRanges.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 14.08.25.
//

import Foundation

extension FloatingPoint {
    private func interpolated(
        fromLowerBound: Self,
        fromUpperBound: Self,
        toLowerBound: Self,
        toUpperBound: Self
    ) -> Self {
        let positionInRange = (self - fromLowerBound) / (fromUpperBound - fromLowerBound)
        return (positionInRange * (toUpperBound - toLowerBound)) + toLowerBound
    }

    func interpolate(from fromRange: Range<Self>, to targetRange: Range<Self>) -> Self {
        return interpolated(
            fromLowerBound: fromRange.lowerBound,
            fromUpperBound: fromRange.upperBound,
            toLowerBound: targetRange.lowerBound,
            toUpperBound: targetRange.upperBound
        )
    }
}
