//
//  String+CapitalizedFirstLetter.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 17.01.25.
//

import Foundation

nonisolated extension String {
    public func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }

    public mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }
}
