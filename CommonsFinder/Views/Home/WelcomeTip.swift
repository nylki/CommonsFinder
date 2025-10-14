//
//  WelcomeTip.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 25.04.25.
//

import TipKit

struct HomeTip: Tip {
    let id = "HomeTip"

    var options: [any TipOption] {
        MaxDisplayCount(1)
    }

    var title: Text {
        Text("Welcome!")
    }

    var message: Text? {
        Text("Here you will find your uploads, drafts, recently viewed media and more.")
    }

    var image: Image? {
        Image(systemName: "house.fill")
    }
}
