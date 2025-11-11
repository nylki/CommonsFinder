//
//  WikidataCache.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 06.11.25.
//


//
//  AttributedString.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 26.10.24.
//

import Foundation
import ObservableLRUCache
import os.log

@Observable final class AttributedStringCache {

    // The key is explicitly generic as it could be a Q-item or P-item ID
    private var cache: ObservableLRUCache<String, AttributedString> = .init(countLimit: 250)

    @ObservationIgnored
    private var task: Task<Void, Error>?

    @ObservationIgnored
    private var unresolvedStrings: Set<String> = []

    static let shared: AttributedStringCache = AttributedStringCache()

    subscript(stringOrHtml: String) -> AttributedString? {
        if let entry = cache.value(forKey: stringOrHtml) { return entry }
        unresolvedStrings.insert(stringOrHtml)
        resolveStrings()
        return nil
    }

    private func resolveStrings() {
        task?.cancel()
        task = Task<Void, Error> {
            try await Task.sleep(for: .milliseconds(5))
            try Task.checkCancellation()

            for (string, attributedString) in await generateAttributedStrings(from: unresolvedStrings) {
                cache.setValue(attributedString, forKey: string)
            }
            //            logger.info("resolved \(self.unresolvedStrings.count) strings.")
            unresolvedStrings.removeAll()
            task = nil
        }
    }

    @concurrent func generateAttributedStrings(from strings: some Collection<String>) async -> [(String, AttributedString)] {
        var result: [(String, AttributedString)] = []
        for string in strings {
            let attributedString = await AttributedString(htmlOrString: string)
            result.append((string, attributedString))
        }
        return result
    }
}
