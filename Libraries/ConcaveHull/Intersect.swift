//
//  Intersect.swift
//  Hull
//
//  Created by Sany Maamari on 09/03/2017.
//  Copyright © 2017 AppProviders. All rights reserved.
//  (c) 2014-2016, Andrii Heonia
//  Hull.js, a JavaScript library for concave hull generation by set of points.
//  https://github.com/AndriiHeonia/hull
//

import Foundation

nonisolated class Intersect {
    var isIntersect: Bool = false

    init(_ seg1: [Point], _ seg2: [Point]) {
        let segment1 = seg1[0]
        let segment2 = seg1[1]
        let segment3 = seg2[0]
        let segment4 = seg2[1]
        isIntersect = ccw(segment1, segment3, segment4) != ccw(segment2, segment3, segment4) &&
            ccw(segment1, segment2, segment3) != ccw(segment1, segment2, segment4)
    }

    private func ccw(_ seg1: Point, _ seg2: Point, _ seg3: Point) -> Bool {
        let ccw = ((seg3.y - seg1.y) * (seg2.x - seg1.x)) - ((seg2.y - seg1.y) * (seg3.x - seg1.x))
        return ccw > 0 ? true : ccw < 0 ? false : true
    }
}
