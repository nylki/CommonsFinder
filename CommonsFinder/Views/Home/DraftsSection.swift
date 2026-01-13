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
    @Previewable @Environment(\.appDatabase) var appDatabase
    @Previewable @Query(AllDraftsRequest()) var drafts

    ScrollView(.vertical) {
        DraftsSection(drafts: drafts)
    }
    .shadow(radius: 30)
    .task {
        _ = try? appDatabase.deleteAllDrafts()
        try? appDatabase.upsert(
            .makeRandomDraft(id: "1", uploadPossibleStatus: .uploadPossible)
        )
    }
}

#Preview("Error Upload", traits: .previewEnvironment(uploadSimulation: .withErrors)) {
    @Previewable @Environment(\.appDatabase) var appDatabase
    @Previewable @Query(AllDraftsRequest()) var drafts

    ScrollView(.vertical) {
        DraftsSection(drafts: drafts)
    }
    .shadow(radius: 30)
    .task {
        _ = try? appDatabase.deleteAllDrafts()
        try? appDatabase.upsert(
            .makeRandomDraft(id: "2", uploadPossibleStatus: .uploadPossible)
        )
    }
}
