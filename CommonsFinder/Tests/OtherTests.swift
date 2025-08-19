//
//  OtherTests.swift
//  CommonsFinderTests
//
//  Created by Tom Brewe on 14.08.25.
//

import Foundation
import Testing

@Test(arguments: [
    (5, 0..<10, 0..<1, 0.5),
    (-1, -100..<0, 0..<1, 0.99),
    (0, 0..<2, 0..<1, 0.0),
    (125, 120..<170, 0..<1, 0.1),
])
func testRangeInterpolation(v: Double, from: Range<Double>, to: Range<Double>, expected: Double) {

    #expect(v.interpolate(from: from, to: to) == expected)
}
