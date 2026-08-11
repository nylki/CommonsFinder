//
//  MultiDraftDateSpreadTip.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 14.07.26.
//

import TipKit

struct MultiDraftDateSpreadTip: Tip {
    let id: String

    init(multiDraftID: MultiDraft.MultiDraftID?) {
        if let multiDraftID {
            id = "MultiDraftDateSpreadTip-\(multiDraftID)"
        } else {
            // for nil-ids (which are drafts not yet persisted in DB) it's ok to just use a UUID here.
            id = UUID().uuidString
        }
    }

    var options: [any TipOption] {
        IgnoresDisplayFrequency(true)
    }

    var title: Text {
        Text("Files from different days")
    }

    var message: Text? {
        Text("Some files were created on different days. Consider double-checking them and be mindful when adding captions and categories.")
    }

    var image: Image? {
        Image(systemName: "calendar.badge.exclamationmark")
    }
}
