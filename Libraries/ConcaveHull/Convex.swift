////
////  Convex.swift
////  Hull
////
////  Created by Sany Maamari on 09/03/2017.
////  Copyright © 2017 AppProviders. All rights reserved.
////  (c) 2014-2016, Andrii Heonia
////  Hull.js, a JavaScript library for concave hull generation by set of points.
////  https://github.com/AndriiHeonia/hull
////
//
//import Foundation
//
//nonisolated class Convex {
//    var convex: [Point] = [Point]()
//
//    init(_ pointSet: [Point]) {
//        let upper = upperTangent(pointSet)
//        let lower = lowerTangent(pointSet)
//        convex = lower + upper
//        convex.append(convex[0])
//    }
//
//    private func cross(_ o: Point, _ a: Point, _ b: Point) -> Double {
//        return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
//    }
//
//    private func upperTangent(_ pointSet: [Point]) -> [Point] {
//        var lower = [Point]()
//        lower.reserveCapacity(pointSet.count)
//        for point in pointSet {
//            while lower.count >= 2 && (cross(lower[lower.count - 2], lower[lower.count - 1], point) <= 0) {
//                _ = lower.popLast()
//            }
//            lower.append(point)
//        }
//        _ = lower.popLast()
//        return lower
//    }
//
//    private func lowerTangent(_ pointSet: [Point]) -> [Point] {
//        let reversed = pointSet.reversed()
//        var upper = [Point]()
//        upper.reserveCapacity(pointSet.count)
//        for point in reversed {
//            while upper.count >= 2 && (cross(upper[upper.count - 2], upper[upper.count - 1], point) <= 0) {
//                _ = upper.popLast()
//            }
//            upper.append(point)
//        }
//        _ = upper.popLast()
//        return upper
//    }
//
//}
