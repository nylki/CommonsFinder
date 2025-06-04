//
//  ExpandingButtonStyle.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 07.10.24.
//

import SwiftUI

struct ExpandingButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .bold()
            .fontWeight(configuration.isPressed ? .black : .regular)
            .frame(maxWidth: .infinity)
            .padding()
            .background(.background)
            .clipShape(.rect(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(lineWidth: configuration.isPressed ? 3 : 2)

            }
            .opacity(isEnabled ? 1 : 0.5)
            .animation(.snappy) {
                $0.scaleEffect(configuration.isPressed ? 0.95 : 1)
            }
            .animation(.spring, value: configuration.isPressed)


    }
}

struct ExpandingLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        Label(
            title: {
                configuration.title
            },
            icon: {
                configuration.icon
            }
        )
        .frame(maxWidth: .infinity)
    }
}

#Preview("ExpandingButtonStyle") {
    VStack {
        Button(action: { print("Pressed") }) {
            Label("Press Me", systemImage: "star")
        }

        Button(action: { print("Pressed") }) {
            Label("Press Me", systemImage: "star")
        }
        .backgroundStyle(Color.green)

        Button(action: { print("Pressed") }) {
            Label("Press Me", systemImage: "star")
                .disabled(true)
        }

    }
    .padding()
    .buttonStyle(ExpandingButtonStyle())
}
