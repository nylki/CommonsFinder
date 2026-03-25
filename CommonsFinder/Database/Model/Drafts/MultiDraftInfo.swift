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
    
    var id: MultiDraft.ID {
        multiDraft.id
    }

    init(multiDraft: MultiDraft, drafts: [MediaFileDraft]) {
        self.multiDraft = multiDraft
        self.drafts = drafts
    }
}
