//
//  TitleAndTrailingIcon.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 02.04.26.
//

import Foundation
import SwiftUI

struct TitleAndTrailingIcon: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.title
            configuration.icon
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
    .labelStyle(TitleAndTrailingIcon())
}
