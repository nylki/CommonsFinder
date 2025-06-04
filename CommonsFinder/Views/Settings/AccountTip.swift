//
//  AccountTip.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 10.05.25.
//

import TipKit

struct AccountTip: Tip {
    let id = "AccountTip"

    var options: [any TipOption] {
        MaxDisplayCount(1)
    }
    var title: Text {
        Text("Wikimedia Account")
    }

    var message: Text? {
        Text("If you want to contribute your own photos to Wikimedia Commons, you need an account.")
    }

    var image: Image? {
        Image(systemName: "person.crop.circle")
    }
}
