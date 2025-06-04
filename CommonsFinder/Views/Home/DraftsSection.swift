//
//  DraftsSection.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 23.12.24.
//

import GRDBQuery
import SwiftUI

struct DraftsSection: View {
    let drafts: [MediaFileDraft]

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 20) {
                ForEach(drafts) { draft in
                    DraftFileListItem(draft: draft)
                }
            }
            .padding(.bottom)
        }
        .scenePadding()
    }
}

#Preview("Regular Upload", traits: .previewEnvironment(uploadSimulation: .regular)) {
    ScrollView(.vertical) {
        DraftsSection(drafts: [.makeRandomDraft(id: "1")])
    }
    .shadow(radius: 30)

}

#Preview("Error Upload", traits: .previewEnvironment(uploadSimulation: .withErrors)) {
    ScrollView(.vertical) {
        DraftsSection(drafts: [.makeRandomDraft(id: "1")])
    }
    .shadow(radius: 30)
}
