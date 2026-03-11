//
//  MultiDraftSheetModifier.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.03.26.
//

import SwiftUI

struct MultiDraftSheetModifier: ViewModifier {
    @Binding var draftedFileModels: [MediaFileDraftModel]?

    func body(content: Content) -> some View {
        content
            .sheet(item: $draftedFileModels) { model in
                NavigationStack {
                    Color.red.overlay {
                        Text("Multiple files \(model.count)")
                    }

                }
            }
    }
}
