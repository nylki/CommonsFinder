//
//  View+navigationSubtitle.swift
//  CommonsFinder
//
//  Created by Tom on 16.07.26.
//

import Foundation
import SwiftUI

private struct NavigationSubtitleFallbackModifier: ViewModifier {
    let subtitle: Text
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .navigationSubtitle(subtitle)
        } else {
            content
        }
    }
}

extension View {
    @ViewBuilder
    func navigationSubtitleFallback(subtitle: Text) -> some View {
        self.modifier(NavigationSubtitleFallbackModifier(subtitle: subtitle))
    }
}
