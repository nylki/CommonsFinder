//
//  DraftsSection.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 23.12.24.
//

import GRDBQuery
import SwiftUI

private enum DraftWrapper: Equatable, Identifiable {
    case single(MediaFileDraft)
    case multi(MultiDraftInfo)

    var addedDate: Date {
        switch self {
        case .single(let mediaFileDraft):
            mediaFileDraft.addedDate
        case .multi(let multiDraftInfo):
            multiDraftInfo.multiDraft.addedDate
        }
    }

    var id: String {
        switch self {
        case .single(let mediaFileDraft):
            mediaFileDraft.id
        case .multi(let multiDraftInfo):
            String(multiDraftInfo.id ?? Int64(multiDraftInfo.hashValue))
        }
    }
}


struct DraftsSection: View {
    private let allDrafts: [DraftWrapper]

    init(drafts: [MediaFileDraft], multiDrafts: [MultiDraftInfo]) {
        let single = drafts.map { DraftWrapper.single($0) }
        let multi = multiDrafts.map { DraftWrapper.multi($0) }
        let allSorted = (single + multi).sorted(by: \.addedDate)
        allDrafts = allSorted
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 20) {
                ForEach(allDrafts) { draft in
                    switch draft {
                    case .multi(let draft):
                        MultiDraftListItem(multiDraftInfo: draft)
                    case .single(let draft):
                        DraftListItem(draft: draft)
                    }
                }
            }
            .scenePadding()
        }
    }
}

#Preview("Regular Upload", traits: .previewEnvironment(uploadSimulation: .regular)) {
    @Previewable @Environment(\.appDatabase) var appDatabase
    @Previewable @Query(AllSingleDraftsRequest()) var drafts
    @Previewable @Query(AllMultiDraftsRequest()) var multiDrafts

    ScrollView(.vertical) {
        DraftsSection(drafts: drafts, multiDrafts: multiDrafts)
    }
    .shadow(radius: 30)
    .task {
        _ = try? appDatabase.deleteAllDrafts()
        _ = try? appDatabase.upsert(
            .makeRandomDraft(id: "1", uploadPossibleStatus: .uploadPossible)
        )
        _ = try? appDatabase.upsertAndFetch(.makeRandom(id: 6, imageCount: 5, uploadPossibleStatus: .uploadPossible))
        _ = try? appDatabase.upsertAndFetch(.makeRandom(id: 5, imageCount: 4, uploadPossibleStatus: .uploadPossible))
        _ = try? appDatabase.upsertAndFetch(.makeRandom(id: 4, imageCount: 3, uploadPossibleStatus: .uploadPossible))
        _ = try? appDatabase.upsertAndFetch(.makeRandom(id: 3, imageCount: 2, uploadPossibleStatus: .uploadPossible))
    }
}

#Preview("Error Upload", traits: .previewEnvironment(uploadSimulation: .withErrors)) {
    @Previewable @Environment(\.appDatabase) var appDatabase
    @Previewable @Query(AllSingleDraftsRequest()) var drafts
    @Previewable @Query(AllMultiDraftsRequest()) var multiDrafts

    ScrollView(.vertical) {
        DraftsSection(drafts: drafts, multiDrafts: multiDrafts)
    }
    .shadow(radius: 30)
    .task {
        _ = try? appDatabase.deleteAllDrafts()
        _ = try? appDatabase.upsert(
            .makeRandomDraft(id: "7", uploadPossibleStatus: .uploadPossible))

        _ = try? appDatabase.upsertAndFetch(.makeRandom(id: 8, imageCount: 5, uploadPossibleStatus: .uploadPossible))

    }
}

#Preview("Previous Error Upload", traits: .previewEnvironment(uploadSimulation: .withErrors)) {
    @Previewable @Environment(\.appDatabase) var appDatabase
    @Previewable @Query(AllSingleDraftsRequest()) var drafts
    @Previewable @Query(AllMultiDraftsRequest()) var multiDrafts

    ScrollView(.vertical) {
        DraftsSection(drafts: drafts, multiDrafts: multiDrafts)
    }
    .shadow(radius: 30)
    .task {
        _ = try? appDatabase.deleteAllDrafts()
        _ = try? appDatabase.upsert(
            .makeRandomDraft(
                id: "9", uploadPossibleStatus: .uploadPossible, publishingState: MediaFileDraft.PublishingState.unstashingFile(filekey: "12345"),
                publishingError: MediaFileDraft.PublishingError.error(errorDescription: "Some Error", recoverySuggestion: "Retry?"))
        )


        _ = try? appDatabase.upsertAndFetch(.makeRandom(id: 10, imageCount: 5, uploadPossibleStatus: .uploadPossible, finishedWithErrors: true))
    }
}
