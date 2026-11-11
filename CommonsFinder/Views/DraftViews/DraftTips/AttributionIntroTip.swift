//
//  AttributionIntroTip.swift
//  CommonsFinder
//
//  Created by Tom on 25.10.26.
//


import TipKit

struct AttributionIntroTip: Tip {
    let isAutoPatrolUser: Bool
    let id = "AttributionIntroTip"


    var title: Text {
        Text("source & attribution details")
    }

    var message: Text? {
        Text(
            "All media uploaded to Wikimedia Commons are free for anyone to use and share anywhere on internet or off internet. To ensure the work you upload is copyright-free, **please provide the following information**."
        )
    }

    //    var actions: [Action] {
    //        Action(id: "learn-more", title: "Learn more")
    //    }


    var options: [any TipOption] {
        if isAutoPatrolUser {
            return [MaxDisplayCount(1)]
        } else {
            return []
        }
    }

    var image: Image? {
        nil
    }


}
