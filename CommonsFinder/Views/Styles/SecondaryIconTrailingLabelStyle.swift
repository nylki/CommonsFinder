//
//  IconTrailingLabelStyle.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 23.12.24.
//

import SwiftUI

struct SecondaryIconTrailingLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.title
            configuration.icon
                .foregroundStyle(.secondary)

            Spacer()
        }
    }
}

#Preview {
    VStack {
        Label("Title 1", systemImage: "star")
        Label("Title 2", systemImage: "square")
        Label("Title 3", systemImage: "circle")
    }
    .labelStyle(SecondaryIconTrailingLabelStyle())
}
