//
//  CircularProgressShape.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 14.10.25.
//

import SwiftUI

@Animatable
struct CircularProgressShape: Shape {
    /// 0...1
    var progress: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let clamped = max(0, min(1, progress))

        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)

        let start = Angle.degrees(-90)
        let end = Angle.degrees(-90 + 360 * clamped)


        path.addArc(
            center: center,
            radius: radius,
            startAngle: start,
            endAngle: end,
            clockwise: false
        )

        return path
    }

}


#Preview {
    VStack {
        CircularProgressShape(progress: 0.0)
        CircularProgressShape(progress: 1 / 3)
        CircularProgressShape(progress: 0.5)
        CircularProgressShape(progress: 0.9)
    }
}
