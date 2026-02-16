//
//  ImageAnalysisResult.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.07.25.
//

import Foundation

struct ImageAnalysisResult: Equatable, Hashable, CustomDebugStringConvertible {
    var isLowQuality: Bool?
    var nearbyCategories: [Category]
    var faceCount: Int?

    var debugDescription: String {
        let debugCategoriesString: String =
            nearbyCategories
            .compactMap { $0.label ?? $0.wikidataId ?? $0.commonsCategory }
            .joined(separator: ",")

        return "lq:\(isLowQuality?.description ?? "unknown"), face count: \(faceCount?.description ?? "-")\n nearbyCategories: [\(debugCategoriesString)]"
    }
}
