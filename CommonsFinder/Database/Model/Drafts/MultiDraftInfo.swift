//
//  MultiDraftInfo.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 13.03.26.
//

import Foundation
import GRDB

nonisolated struct MultiDraftInfo: FetchableRecord, Equatable, Hashable, Decodable, Identifiable {
    var multiDraft: MultiDraft
    var drafts: [MediaFileDraft]

    var combinedFileSizeInByte: Int64

    var id: MultiDraft.ID {
        multiDraft.id
    }


    var publishingErrorUploadCount: Int {
        guard multiDraft.publishingState != nil else {
            return 0
        }

        return drafts.filter { $0.publishingError != nil }.count
    }

    var publishingSuccessUploadCount: Int {
        guard multiDraft.publishingState != nil else {
            return 0
        }
        return drafts.filter { $0.publishingState == .published }.count
    }

    init(multiDraft: MultiDraft, drafts: [MediaFileDraft], combinedFileSizeInByte: Int64? = nil) {

        let draftsHaveAlreadyAssignedIndices = drafts.allSatisfy({ $0.multiDraftIndex != nil })

        if draftsHaveAlreadyAssignedIndices {
            self.drafts = drafts
        } else {
            self.drafts = drafts.enumerated()
                .map { (idx, draft) in
                    var draft = draft
                    draft.multiDraftIndex = idx
                    return draft
                }
        }

        self.multiDraft = multiDraft

        if let combinedFileSizeInByte {
            self.combinedFileSizeInByte = combinedFileSizeInByte
        } else {
            self.combinedFileSizeInByte = drafts.reduce(0) { combined, draft in
                combined + (draft.size ?? 0)
            }
        }

    }
}
