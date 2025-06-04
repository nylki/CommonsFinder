//
//  ImageButtonStyle.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 10.05.25.
//

import SwiftUI

struct ImageButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .clipShape(.rect(cornerRadius: 15))
            .animation(.snappy) {
                $0.scaleEffect(configuration.isPressed ? 0.95 : 1)
            }
    }
}

#Preview("ImageButtonStyle") {
    Button(action: { print("Pressed") }) {
        Label("Press Me", systemImage: "star")
    }
    .buttonStyle(ImageButtonStyle())
}
