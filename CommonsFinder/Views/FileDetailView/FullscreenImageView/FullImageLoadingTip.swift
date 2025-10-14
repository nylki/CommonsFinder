//
//  FullImageLoadingTip.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 10.10.25.
//

import TipKit

struct FullImageLoadingTip: Tip {
    let id = "FullImageLoadingTip"

    static let didLoadFullImageManually: Event = Event(id: "didLoadFullImageManually")

    var rules: [Rule] {
        #Rule(Self.didLoadFullImageManually) {
            $0.donations.donatedWithin(.weeks(4)).count < 1
        }
    }

    var title: Text {
        Text("slow or expensive internet connection")
    }

    var message: Text? {
        Text("The original full-sized image was not loaded automatically. Turn on Wifi or explicitly load the full image here.")
    }

    var image: Image? {
        Image(systemName: "wifi.exclamationmark")
    }
}
