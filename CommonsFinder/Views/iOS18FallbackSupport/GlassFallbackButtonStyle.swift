//
//  GlassFallbackButtonStyle.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 07.10.25.
//

import SwiftUI

extension View {
    @ViewBuilder
    func glassButtonStyle(prominent: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                buttonStyle(.glassProminent)
            } else {
                buttonStyle(.glass)
            }
        } else {
            buttonStyle(GlassFallbackButtonStyle(prominent: prominent))
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
    let prominent: Bool

    @Environment(\.isEnabled) private var isEnabled: Bool
    func makeBody(configuration: Configuration) -> some View {

        if prominent {
            configuration.label
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(.thinMaterial, in: Capsule())
                .background(isEnabled ? .accent : .clear, in: Capsule())
                .clipShape(Capsule())
                .contentShape(Capsule())
                .opacity(!isEnabled || configuration.isPressed ? 0.5 : 1)
        } else {
            configuration.label
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(.regularMaterial, in: Capsule())
                .clipShape(Capsule())
                .contentShape(Capsule())
                .opacity(!isEnabled || configuration.isPressed ? 0.5 : 1)
        }

    }
}

#Preview {
    VStack {
        Button(action: { print("Pressed") }) {
            Label("Press Me", systemImage: "star")
        }
        .buttonStyle(GlassFallbackButtonStyle(prominent: false))

        Button(action: { print("Pressed") }) {
            Label("Press Me", systemImage: "star")
        }
        .buttonStyle(GlassFallbackButtonStyle(prominent: true))
    }
    .padding()
    .background {
        Image(.debugDraft)
    }
}
