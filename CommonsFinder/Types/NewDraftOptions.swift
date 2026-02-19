//
//  NewDraftOptions.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 01.12.25.
//

import Foundation

struct NewDraftOptions: Sendable, Hashable, Equatable {
    var source: ImportSource? = nil
    var tag: TagItem? = nil

    enum ImportSource {
        case mediaLibrary
        case camera
        case files
    }
}
