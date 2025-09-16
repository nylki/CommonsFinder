//
//  OutlinedTextFieldStyle.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 18.11.24.
//

import SwiftUI

struct OutlinedTextFieldStyle: TextFieldStyle {
    private let outlineColor: Color
    private var message: LocalizedStringResource?

    enum ColorStyle {
        case `default`
        case error
    }

    init(style: ColorStyle? = nil, message: LocalizedStringResource? = nil) {
        outlineColor =
            switch style {
            case .default, .none: .primary
            case .error: .red
            }
        self.message = message
    }

    func _body(configuration: TextField<Self._Label>) -> some View {
        VStack {
            configuration

            if let message {
                fieldErrorText(message)
            }

        }

    }

    private func fieldErrorText(_ message: LocalizedStringResource?) -> some View {
        HStack {
            Image(systemName: "exclamationmark.shield")
                .transition(.scale.animation(.bouncy))
            if let message {
                Text(message)
                    .font(.caption)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.red)
        .frame(minWidth: 50, maxWidth: .infinity)
        .padding(.bottom)
    }
}

#Preview {
    VStack {
        TextField("Preview", text: .constant(""))
            .textFieldStyle(OutlinedTextFieldStyle(style: .error, message: "error"))
    }
    .padding()
}
