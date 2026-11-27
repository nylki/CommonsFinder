//
//  DataDetection.swift
//  CommonsFinder
//
//  Created by Tom on 16.11.26.
//

import DataDetection
import Foundation
import os.log

enum DataDetection {
    @concurrent static func urls(inText text: String) async -> [URL] {
        var result: [URL] = []

        if #available(iOS 26.0, *) {
            for await match in text.dataDetectorMatches([.link]) {
                if case .link(let link) = match.details {
                    result.append(link.url)
                }
            }
        } else {
            logger.warning("url detection not supported returning empty list")
        }

        return result
    }
}
