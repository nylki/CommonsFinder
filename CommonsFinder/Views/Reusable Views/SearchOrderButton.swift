//
//  SearchOrderButton.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 22.01.26.
//

import SwiftUI

struct SearchOrderButton<T: CustomLocalizedStringResourceConvertible & Equatable & Hashable>: View {
    @Binding var searchOrder: T
    let possibleCases: [T]
    var showSelectedInLabel: Bool = false

    var body: some View {

        Menu {
            Picker(selection: $searchOrder) {
                ForEach(possibleCases, id: \.self) { order in
                    Text(order.localizedStringResource)
                        .tag(order)
                }
            } label: {
                Label {
                    Text("Sort by")
                } icon: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        } label: {
            Label {
                if showSelectedInLabel {
                    Text(searchOrder.localizedStringResource)
                } else {
                    Text("Sort by")
                }
            } icon: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .tint(.primary)
            .font(.footnote)
        }
        .glassButtonStyle()
        .animation(.default, value: searchOrder)
    }
}

#Preview {
    @Previewable @State var searchOrder = SearchOrder.oldest
    VStack {
        SearchOrderButton(searchOrder: $searchOrder, possibleCases: SearchOrder.allCases, showSelectedInLabel: false)
        SearchOrderButton(searchOrder: $searchOrder, possibleCases: SearchOrder.allCases, showSelectedInLabel: true)
    }
}
