//
//  SearchBar.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 03.12.24.
//

import SwiftUI

/// Custom SearchBar for situation where .searchable() is not suitable.
struct SearchBar: View {
    @Binding var text: String
    var prompt: LocalizedStringKey?

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
                .frame(width: 20)

            TextField(prompt ?? "", text: $text)
                .padding(7)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "multiply.circle.fill")
                        .foregroundColor(.gray)
                        .padding(.trailing, 8)
                }
            }
        }
        .background(Color(.systemGray6), in: .buttonBorder)

    }
}

#Preview {
    SearchBar(text: .constant("lorem"), prompt: nil)
}
