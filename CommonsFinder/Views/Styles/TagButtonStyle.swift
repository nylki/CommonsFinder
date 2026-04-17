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
            .padding(.top, 4)
            .padding([.horizontal, .bottom], 6)
            .background(.buttonBackground)
            .clipShape(
                UnevenRoundedRectangle(
                    cornerRadii: .init(bottomLeading: 15, bottomTrailing: 15, topTrailing: 15),
                    style: .continuous
                )
            )
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

#Preview {
    Button(action: { print("Pressed") }) {
        Label("Press Me", systemImage: "star")
    }
    .buttonStyle(TagButtonStyle())
}
