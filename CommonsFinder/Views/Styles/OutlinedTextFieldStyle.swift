//
//  OutlinedTextFieldStyle.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 18.11.24.
//

import SwiftUI

struct OutlinedTextFieldStyle: TextFieldStyle {
    private let outlineColor: Color


    enum ColorStyle {
        case `default`
        case error
    }

    init(style: ColorStyle? = nil) {
        outlineColor =
            switch style {
            case .default, .none: .primary
            case .error: .red
            }
    }

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(.regularMaterial, in: .buttonBorder)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(outlineColor, lineWidth: 1)
            }
    }
}

#Preview {
    VStack {
        TextField("Preview", text: .constant(""))
            .textFieldStyle(OutlinedTextFieldStyle())
    }
    .padding()
}
