//
//  SingleDraftSheetModifier.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.03.26.
//

import SwiftUI

struct SingleDraftSheetModifier: ViewModifier {
    @Binding var draftedFileModel: MediaFileDraftModel?

    func body(content: Content) -> some View {
        content
            .sheet(item: $draftedFileModel) { model in
                NavigationStack {
                    SingleImageDraftView(model: model)
                }
            }
    }
}
