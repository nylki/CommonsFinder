//
//  H3.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 03.03.25.
//

import Foundation
import H3kit

extension H3 {
    // This is just a rough estimation, to be adjusted.
    public static func bestH3Resolution(forScreenArea screenArea: Double) -> Resolution {
        let idealVisibleCellCount = 4
        let idealHexArea = screenArea / Double(idealVisibleCellCount)

        var idealRes: Resolution = .zero
        // Find the resolution where the hexArea is closest to idealHexArea
        for res in Resolution.allCases {
            if abs(idealHexArea - res.hexSqmArea) < idealRes.hexSqmArea {
                idealRes = res
            }
        }

        return idealRes
    }
}


extension H3.Resolution {
    /// A cell is a hexagong or pentagon, so the circle is just a rough approximation in meter based on the area
    /// and will not cover points at the corners of the polygon.
    var approxCircleRadius: Double {
        (Double(hexSqmArea) / Double.pi).squareRoot()
    }
}
