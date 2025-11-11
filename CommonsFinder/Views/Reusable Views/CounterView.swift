//
//  CounterView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 09.11.25.
//

import SwiftUI

struct CounterView: View {
    let current: Int
    let max: Int

    var body: some View {
        ZStack {
            let text = "\(current) / \(max)"
            Text(text)
                .frame(width: Double(text.count) * 10.0)
                .contentTransition(.numericText(value: Double(current)))
        }
        .animation(.default, value: current)
    }
}
