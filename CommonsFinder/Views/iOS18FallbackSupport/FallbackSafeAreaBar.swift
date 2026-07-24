//
//  FallbackSafeAreaBar.swift
//  CommonsFinder
//
//  Created by Tom on 22.07.26.
//

import SwiftUI

struct FallbackSafeAreaBar<C: View>: ViewModifier {
    var edge: VerticalEdge
    var alignment: HorizontalAlignment
    var spacing: CGFloat?
    @ViewBuilder var barContent: C

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.safeAreaBar(edge: edge, alignment: alignment, spacing: spacing) {
                barContent
            }
        } else {
            content.safeAreaInset(edge: edge, alignment: alignment, spacing: spacing) {
                barContent
            }
        }
    }
}

extension View {
    @ViewBuilder
    func fallbackSafeAreaBar<C: View>(
        edge: VerticalEdge,
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder barContent: @escaping () -> C
    ) -> some View {
        modifier(
            FallbackSafeAreaBar(
                edge: edge,
                alignment: alignment,
                spacing: spacing,
                barContent: barContent
            )
        )
    }
}

#Preview {
    Text("Hello, world!")
        .fallbackSafeAreaBar(edge: .top, alignment: .center, spacing: nil) {
            Color.yellow.frame(width: 200, height: 50)
        }
}
