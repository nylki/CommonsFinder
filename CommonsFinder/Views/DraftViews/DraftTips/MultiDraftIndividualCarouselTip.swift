//
//  MultiDraftIndividualCarouselTip2.swift
//  CommonsFinder
//
//  Created by Tom on 24.07.26.
//


import TipKit

struct MultiDraftIndividualCarouselTip: Tip {
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
