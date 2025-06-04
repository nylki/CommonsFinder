//
//  CapsuleLinkButtonStyle.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 19.03.25.
//

import Foundation
import SwiftUI

struct CapsuleLinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Material.thin, in: Capsule())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

#Preview {
    Button(action: { print("Pressed") }) {
        Label("Press Me", systemImage: "star")
    }
    .buttonStyle(CapsuleLinkButtonStyle())
}
