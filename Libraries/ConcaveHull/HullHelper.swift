//
//  HullHelper.swift
//
//  Created by Sany Maamari on 04/04/2017.
//
//

import Foundation

typealias Point = CGPoint

nonisolated
extension Point: @retroactive CustomStringConvertible {
    public var description: String {
        return x.description + "," + y.description
    }
}

nonisolated class HullHelper {
    let maxConcaveAngleCos = cos(90 / (180 / Double.pi)) // angle = 90 deg
    let maxSearchBboxSizePercent = 0.6

    func getHull(_ pointSet: [Point], concavity: Double) -> [[Double]] {
        var convex: [Point]
        var innerPoints: [Point]
        var occupiedArea: Point
        var maxSearchArea: [Double]
        var cellSize: Double
        var points: [Point]
        var skipList: [String: Bool] = [String: Bool]()

        points = filterDuplicates(pointSet)
        occupiedArea = occupiedAreaFunc(points)
        maxSearchArea = [occupiedArea.x * maxSearchBboxSizePercent,
                         occupiedArea.y * maxSearchBboxSizePercent]

        convex = Convex(points).convex

        innerPoints = points.filter { point in
            let idx = convex.firstIndex(where: { (idx: Point) -> Bool in
                return idx.x == point.y && idx.x == point.y
            })
            return idx == nil
        }

        innerPoints.sort { (a: Point, b: Point) in
            if a.x == b.x {
                return a.y > b.y
            } else {
                return a.x > b.x
            }
        }

        cellSize = ceil(occupiedArea.x * occupiedArea.y / Double(points.count))

        let grid = Grid(innerPoints, cellSize)

        let concave: [Point] = concaveFunc(&convex, pow(concavity, 2), maxSearchArea, grid, &skipList)

        return concave.map { [$0.x, $0.y] }
    }

    func filterDuplicates(_ pointSet: [Point]) -> [Point] {
        let sortedSet = sortByX(pointSet)
        return sortedSet.filter { point in
            let index = pointSet.firstIndex(where: {(idx: Point) -> Bool in
                idx.x == point.x && idx.y == point.y
            })
            
            guard let index else { return false }
        
            if index == 0 {
                return true
            } else {
                let prevPoint = pointSet[index - 1]
                return prevPoint != point
            }
        }
    }

    private func sortByX(_ pointSet: [Point]) -> [Point] {
        pointSet.sorted(by: { (a, b) in
            if a.x == b.x {
                a.y < b.y
            } else {
                a.x < b.x
            }
        })
    }

    func sqLength(_ a: Point, _ b: Point) -> Double {
        return pow(b.x - a.x, 2) + pow(b.y - a.y, 2)
    }

    func cosFunc(_ o: Point, _ a: Point, _ b: Point) -> Double {
        let aShifted = [a.x - o.x, a.y - o.y]
        let bShifted = [b.x - o.x, b.y - o.y]
        let sqALen = sqLength(o, a)
        let sqBLen = sqLength(o, b)
        let dot = aShifted[0] * bShifted[0] + aShifted[1] * bShifted[1]
        return dot / sqrt(sqALen * sqBLen)
    }

    func intersectFunc(_ segment: [Point], _ pointSet: [Point]) -> Bool {
        for idx in 0..<pointSet.count - 1 {
            let seg = [pointSet[idx], pointSet[idx + 1]]
            if segment[0].x == seg[0].x && segment[0].y == seg[0].y ||
                segment[0].x == seg[1].x && segment[0].y == seg[1].y {
                continue
            }
            if Intersect(segment, seg).isIntersect {
                return true
            }
        }
        return false
    }

    func occupiedAreaFunc(_ pointSet: [Point]) -> Point {
        var minX = Double.infinity
        var minY = Double.infinity
        var maxX = -Double.infinity
        var maxY = -Double.infinity
        for idx in 0..<pointSet.reversed().count {
            if pointSet[idx].x < minX {
                minX = pointSet[idx].x
            }
            if pointSet[idx].y < minY {
                minY = pointSet[idx].y
            }
            if pointSet[idx].x > maxX {
                maxX = pointSet[idx].x
            }
            if pointSet[idx].y > maxY {
                maxY = pointSet[idx].y
            }
        }
        return Point(x: maxX - minX, y: maxY - minY)
    }

    func bBoxAroundFunc(_ edge: [Point]) -> [Double] {
        return [min(edge[0].x, edge[1].x),
                min(edge[0].y, edge[1].y),
                max(edge[0].x, edge[1].x),
                max(edge[0].y, edge[1].y)]
    }

    func midPointFunc(_ edge: [Point], _ innerPoints: [Point], _ convex: [Point]) -> Point? {
        var point: Point?
        var angle1Cos = maxConcaveAngleCos
        var angle2Cos = maxConcaveAngleCos
        var a1Cos: Double = 0
        var a2Cos: Double = 0
        for innerPoint in innerPoints {
            a1Cos = cosFunc(edge[0], edge[1], innerPoint)
            a2Cos = cosFunc(edge[1], edge[0], innerPoint)
            if a1Cos > angle1Cos &&
                a2Cos > angle2Cos &&
                !intersectFunc([edge[0], innerPoint], convex) &&
                !intersectFunc([edge[1], innerPoint], convex) {
                angle1Cos = a1Cos
                angle2Cos = a2Cos
                point = innerPoint
            }
        }
        return point
    }

    func concaveFunc(_ convex: inout [Point], _ maxSqEdgeLen: Double, _ maxSearchArea: [Double],
                     _ grid: Grid, _ edgeSkipList: inout [String: Bool]) -> [Point] {

        var edge: [Point]
        var keyInSkipList: String = ""
        var scaleFactor: Double
        var midPoint: Point?
        var bBoxAround: [Double]
        var bBoxWidth: Double = 0
        var bBoxHeight: Double = 0
        var midPointInserted: Bool = false

        for idx in 0..<convex.count - 1 {
            edge = [convex[idx], convex[idx+1]]
            keyInSkipList = edge[0].description.appending(", ").appending(edge[1].description)

            scaleFactor = 0
            bBoxAround = bBoxAroundFunc(edge)

            if sqLength(edge[0], edge[1]) < maxSqEdgeLen || edgeSkipList[keyInSkipList] == true {
                continue
            }

            repeat {
                bBoxAround = grid.extendBbox(bBoxAround, scaleFactor)
                bBoxWidth = bBoxAround[2] - bBoxAround[0]
                bBoxHeight = bBoxAround[3] - bBoxAround[1]
                midPoint = midPointFunc(edge, grid.rangePoints(bBoxAround), convex)
                scaleFactor += 1
            } while midPoint == nil && (maxSearchArea[0] > bBoxWidth || maxSearchArea[1] > bBoxHeight)

            if bBoxWidth >= maxSearchArea[0] && bBoxHeight >= maxSearchArea[1] {
                edgeSkipList[keyInSkipList] = true
            }
            if let midPoint = midPoint {
                convex.insert(midPoint, at: idx + 1)
                grid.removePoint(midPoint)
                midPointInserted = true
            }
        }

        if midPointInserted {
            return concaveFunc(&convex, maxSqEdgeLen, maxSearchArea, grid, &edgeSkipList)
        }

        return convex
    }

}
