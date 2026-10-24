//
//  EnvironmentValues+Fallbacks.swift
//  CommonsFinder
//
//  Created by Tom on 24.10.26.
//

import SwiftUI

extension EnvironmentValues {
    var toolbarVerticalEdgeFallback: HorizontalEdge? {
        if #available(anyAppleOS 27.1, *) {
            toolbarVerticalEdge
        } else {
            nil
        }
    }
}
