//
//  MultiDraftOverview.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 29.05.26.
//

import TipKit

struct MultiDraftOverviewTip: Tip {
    let id = "MultiDraftOverviewTip"

    var options: [any TipOption] {
        MaxDisplayCount(2)
    }

    var title: Text {
        Text("Review your files before uploading")
    }

    var message: Text? {
        Text(
            "Here you can adjust fields for individual files if necessary."
        )
    }

    var image: Image? {
        Image(systemName: "hand.raised")
    }
}
