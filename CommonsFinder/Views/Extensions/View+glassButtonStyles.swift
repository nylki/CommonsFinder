//
//  View+glassButtonStyles.swift
//  CommonsFinder
//
//  Created by Tom on 30.09.26.
//

import SwiftUI

extension View {
    @ViewBuilder
    func glassButtonStyle(prominent: Bool = false) -> some View {
        if prominent {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.glass)
        }
    }
}
