//
//  DeepCategoryToggle.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 22.01.26.
//

import SwiftUI

struct DeepCategoryToggle: View {
    @Binding var enabled: Bool

    var body: some View {
        Button {
            enabled.toggle()
        } label: {
            Label("Include Subcategories", systemImage: "list.bullet.indent")
                .contentTransition(.symbolEffect)
                .tint(.primary)
                .font(.footnote)
        }
        .glassButtonStyle(prominent: enabled)
        .animation(.default, value: enabled)
        .sensoryFeedback(.impact, trigger: enabled)
    }
}

#Preview {
    @Previewable @State var enabled = false
    DeepCategoryToggle(enabled: $enabled)
}
