//
//  FilenameTip.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 23.11.24.
//

import TipKit

struct FilenameTip: Tip {
    // see: https://commons.wikimedia.org/wiki/Commons:File_naming

    var title: Text {
        Text("Choose a meaningful filename.")
    }

    var message: Text? {
        Text(
            "It cannot be changed once upload and must be unique! A good filename should be descriptive, appropriate and concise, but also clear and recognizable to a wider audience.\n\n- Avoid abbreviations and random characters\n\n- Including a date and location is often a good idea"
        )
    }

    var actions: [Action] {
        Action(id: "learn-more", title: "Learn more")
    }


    var image: Image? {
        nil
    }
}
