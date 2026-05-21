//
//  MultiDraftSheetModifier.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.03.26.
//

import SwiftUI

struct MultiDraftSheetModifier: ViewModifier {
    @Binding var multiDraftModel: MultiDraftModel?

    func body(content: Content) -> some View {
        content
            .sheet(item: $multiDraftModel) { model in
                NavigationStack {
                    MultiDraftView(model: model)
                }
            }
    }
}
