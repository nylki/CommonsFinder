//
//  Grid.swift
//  Hull
//
//  Created by Sany Maamari on 09/03/2017.
//  Copyright © 2017 AppProviders. All rights reserved.
//  (c) 2014-2016, Andrii Heonia
//  Hull.js, a JavaScript library for concave hull generation by set of points.
//  https://github.com/AndriiHeonia/hull
//

import Foundation
import os.log


nonisolated class Grid {
    var cells = [Int: [Int: [Point]]]()
    var cellSize: Double = 0

    init(_ points: [Point], _ cellSize: Double) {
        self.cellSize = cellSize
        for point in points {
            let cellXY = point2CellXY(point)
            let x = cellXY[0]
            let y = cellXY[1]
            if cells[x] == nil {
                cells[x] = [Int: [Point]]()
            }
            if cells[x]?[y] == nil {
                cells[x]?[y] = [Point]()
            }
            cells[x]?[y]?.append(point)
        }
    }

    func point2CellXY(_ point: Point) -> [Int] {
        guard cellSize != 0 else {
            logger.error("cellSize is 0!")
            return []
        }
        let x = Int(point.x / cellSize)
        let y = Int(point.y / cellSize)
        return [x, y]
    }

    func extendBbox(_ bbox: [Double], _ scaleFactor: Double) -> [Double] {
        let offset = scaleFactor * cellSize
        return [
            bbox[0] - offset,
            bbox[1] - offset,
            bbox[2] + offset,
            bbox[3] + offset
        ]
    }

    func removePoint(_ point: Point) {
        let cellXY = point2CellXY(point)
        let cell = cells[cellXY[0]]![cellXY[1]]!
        var pointIdxInCell = 0
        for idx in 0..<cell.count {
            if cell[idx].x == point.x && cell[idx].y == point.y {
                pointIdxInCell = idx
                break
            }
        }
        cells[cellXY[0]]![cellXY[1]]?.remove(at: pointIdxInCell)
    }

    func rangePoints(_ bbox: [Double]) -> [Point] {
        let tlCellXY = point2CellXY(Point(x: bbox[0], y: bbox[1]))
        let brCellXY = point2CellXY(Point(x: bbox[2], y: bbox[3]))
        var points = [Point]()

        for x in tlCellXY[0]..<brCellXY[0]+1 {
            for y in tlCellXY[1]..<brCellXY[1]+1 {
                points += cellPoints(x, y)
            }
        }
        return points
    }

    func cellPoints(_ xAbs: Int, _ yOrd: Int) -> [Point] {
        if let x = cells[xAbs], let y = x[yOrd] {
            return y
        } else {
            return .init()
        }
    }

}
