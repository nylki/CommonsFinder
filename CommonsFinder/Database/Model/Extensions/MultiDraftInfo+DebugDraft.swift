//
//  MultiDraftInfo+DebugDraft.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 13.03.26.
//

import Foundation

extension MultiDraftInfo {
    /// DEBUG ONLY value, will always be `false` in Release.
    var isDebugDraft: Bool {
        #if DEBUG
            multiDraft.name.starts(with: "DEBUG-DRAFT-")
        #else
            false
        #endif
    }

    static func makeRandom(id: Int64, imageCount: Int, uploadPossibleStatus: UploadPossibleStatus? = nil, finishedWithErrors: Bool = false) -> Self {
        let date: Date = Date(timeIntervalSince1970: .random(in: 1..<5000))

        var randomMultiDraft = MultiDraft(
            id: id,
            addedDate: date,
            name: "DEBUG-DRAFT-Lorem Ipsum dolor sitit",
            nameSuffix: .numbering,
            captionWithDesc: [.init(caption: "Lorem Caption", languageCode: "en")],
            tags: [.init(.earth)],
            license: .CC0,
            author: .appUser,
            source: .own,
            selectedFilenameType: .captionAndDate,
            uploadPossibleStatus: uploadPossibleStatus,
            copiedFieldsIntoSubDrafts: false
        )

        var randomDrafts: [MediaFileDraft] = []

        let publishingState: MultiDraft.PublishingState? =
            if finishedWithErrors {
                MultiDraft.PublishingState(overallProgress: 1, isFinished: true, completedCount: imageCount, totalCount: imageCount)
            } else {
                nil
            }

        for idx in 0..<imageCount {
            var draft = MediaFileDraft.makeRandomDraft(id: "DEBUG-DRAFT-\(id)-\(idx)")
            draft.multiDraftId = id
            draft.multiDraftIndex = idx

            if finishedWithErrors {
                draft.publishingError = .appQuitOrCrash
            }

            randomDrafts.append(draft)
        }


        randomMultiDraft.publishingState = publishingState

        return MultiDraftInfo(
            multiDraft: randomMultiDraft,
            drafts: randomDrafts
        )
    }
}
