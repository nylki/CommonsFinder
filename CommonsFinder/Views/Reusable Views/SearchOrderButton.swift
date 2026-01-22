//
//  SearchOrderButton.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 22.01.26.
//

import SwiftUI

struct SearchOrderButton: View {
    @Binding var searchOrder: SearchOrder
    var body: some View {
        Menu {
            ForEach(SearchOrder.allCases, id: \.self) { order in
                Button(action: { searchOrder = order }) {
                    Label {
                        Text(order.localizedStringResource)
                    } icon: {
                        if order == searchOrder {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label {
                Text(searchOrder.localizedStringResource)
            } icon: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .tint(.primary)
            .padding(.vertical, 5)
            .font(.footnote)
        }
        .glassButtonStyle()
        .animation(.default, value: searchOrder)
    }
}

#Preview {
    @Previewable @State var searchOrder = SearchOrder.oldest
    SearchOrderButton(searchOrder: $searchOrder)
}
