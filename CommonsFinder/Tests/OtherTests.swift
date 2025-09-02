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

@Test(
    "test popFirst", arguments: [[1, 2, 3, 4, 5, 6, 7, 8], [1, 2], [1], []],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
)
func testPopFirst(array: [Int], count: Int) {
    var arrayCopy = array

    let poppedItems = arrayCopy.popFirst(n: count)

    #expect(poppedItems == Array(array.prefix(count)))
    #expect(arrayCopy.count == max(0, array.count - count))
    #expect(arrayCopy == Array(array.dropFirst(count)))
}

@Test("test zippedFlatMap")
func testZippedFlatMap() {
    #expect(zippedFlatMap(["a", "b"], ["x", "y"]) == ["a", "x", "b", "y"])
    #expect(zippedFlatMap([1, 2, 3, 4, 5], [8, 9]) == [1, 8, 2, 9, 3, 4, 5])
    #expect(zippedFlatMap([], [8, 9]) == [8, 9])
    #expect(zippedFlatMap([8, 9], []) == [8, 9])
    #expect(zippedFlatMap([1, 2, 3, 4, 5], [8, 9]) == [1, 8, 2, 9, 3, 4, 5])
    let emptyArray: [Double] = []
    #expect(zippedFlatMap(emptyArray, emptyArray) == [])
}
