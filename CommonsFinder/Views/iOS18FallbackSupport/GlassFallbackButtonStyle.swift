//
//  GlassFallbackButtonStyle.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 07.10.25.
//

import SwiftUI

extension View {
    @ViewBuilder
    func glassButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(GlassFallbackButtonStyle())
        }
    }
}

extension View {
    @ViewBuilder
    func fallbackGlassEffect() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect()
        } else {
            background(.regularMaterial)
        }
    }

    @ViewBuilder
    func fallbackGlassEffect(in shape: some Shape) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(in: shape)
        } else {
            background(.regularMaterial, in: shape)
                .clipShape(shape)
                .contentShape(Capsule())
        }
    }
}


private struct GlassFallbackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(.regularMaterial, in: Capsule())
            .clipShape(Capsule())
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

#Preview {
    Button(action: { print("Pressed") }) {
        Label("Press Me", systemImage: "star")
    }
    .buttonStyle(GlassFallbackButtonStyle())
}
