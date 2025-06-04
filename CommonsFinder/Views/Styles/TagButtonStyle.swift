//
//  TagButtonStyle.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 27.11.24.
//

import SwiftUI

struct TagButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .animation(.default, value: configuration.isPressed)
    }
}

#Preview("TagButtonStyle") {
    Button(action: { print("Pressed") }) {
        Label("Press Me", systemImage: "star")
    }
    .buttonStyle(TagButtonStyle())
}
