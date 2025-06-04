//
//  URL+AppGroupContainer.swift
//  CommonsFinderShareExtension
//
//  Created by Tom Brewe on 03.02.25.
//

import Foundation

extension URL {
    static var shareExtensionContainerURL: URL? {
        let fileManager = FileManager.default
        let groupDirectory = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.CommonsFinder")
        return groupDirectory?.appendingPathComponent("shareExtension")
    }
}
