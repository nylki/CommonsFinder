//
//  String+truncated.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 06.11.25.
//

import Foundation

nonisolated extension String {
    func truncate(to maxLength: Int, trailing: String = "…") -> String {
        guard maxLength > 0 else { return "" }
        guard count > maxLength else { return self }
        let endIndex = index(startIndex, offsetBy: max(0, maxLength))
        return String(self[..<endIndex]) + trailing
    }
}
