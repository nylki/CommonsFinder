//
//  ScrollState.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 23.01.26.
//

import SwiftUI

struct ScrollState: Equatable {
    var lastDirection: Direction = .none
    var phase: ScrollPhase = .idle

    enum Direction {
        case up
        case down
        case none
    }
}
