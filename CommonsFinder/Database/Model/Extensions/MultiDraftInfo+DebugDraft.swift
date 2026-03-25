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
        false
        #else
            return false
        #endif
    }

    static func makeRandom(id: Int64) -> Self {
        let date: Date = Date(timeIntervalSince1970: .random(in: 1..<5000))
        
        let randomMultiDraft = MultiDraft(
            id: id,
            addedDate: date,
            name: "Lorem Ipsum dolor sitit",
            nameSuffix: .numbering,
            nameAdditionalFallbackSuffix: .asciiLetters,
            captionWithDesc: [],
            tags: [],
            license: nil,
            author: nil,
            source: .own,
            selectedFilenameType: .captionAndDate,
            uploadPossibleStatus: nil,
        )
        
        let randomDrafts: [MediaFileDraft] = [1...5].map {
            var draft = MediaFileDraft.makeRandomDraft(id: "\($0)")
            draft.multiDraftId = id
            return draft
        }
        
        return MultiDraftInfo(
            multiDraft: randomMultiDraft,
            drafts: randomDrafts
        )
    }
}
