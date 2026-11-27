//
//  URL+absoluteStringWithoutQueryParams.swift
//  CommonsFinder
//
//  Created by Tom on 27.11.26.
//

import Foundation

nonisolated extension URL {
    var absoluteStringWithoutQueryParams: String {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return absoluteString
        }
        components.query = nil
        components.fragment = nil
        return components.string ?? absoluteString
    }
}
