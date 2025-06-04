//
//  WikidataCache.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 26.10.24.
//

import Algorithms
import CommonsAPI
import Foundation
import GRDB
import SwiftUI
import os.log

@MainActor
@Observable class WikidataCache {
    typealias LanguageCode = String

    // The key is explicitly generic as it could be a Q-item or P-item ID
    private var dictionary: [String: WikidataItem] = [:]

    @ObservationIgnored
    private var task: Task<Void, Error>?

    /// IDs that were tried to access in the subscript but could not be found will be collected here for the debounce duration
    @ObservationIgnored
    private var missingIDs: Set<String> = []

    @ObservationIgnored
    private let appDatabase: AppDatabase

    init(appDatabase: AppDatabase) {
        self.appDatabase = appDatabase
    }

    /// tries to retrieve item from DB and caches it into memory if found for faster access next time
    private func retrieveFromDB(id: String) -> WikidataItem? {
        let item = try? appDatabase.reader.read { db in
            try WikidataItem.find(db, id: id)
        }

        guard let item else { return nil }
        dictionary[id] = item
        return item
    }


    subscript(id: String) -> WikidataItem? {
        let entry = dictionary[id] ?? retrieveFromDB(id: id)

        guard let entry else {
            missingIDs.insert(id)
            fetchMissing()
            return nil
        }

        if entry.preferredLanguageAtFetchDate != Locale.current.wikiLanguageCodeIdentifier {
            missingIDs.insert(id)
            fetchMissing()
        }

        return entry
    }

    func cache(wikidataItem: WikidataItem) {
        dictionary[wikidataItem.id] = wikidataItem
    }

    /// debounced fetch of missing localizations
    ///
    private func fetchMissing() {
        task?.cancel()
        task = Task<Void, Error> {
            try await Task.sleep(for: .milliseconds(50))
            try Task.checkCancellation()

            let chunkedIDs = missingIDs.chunks(ofCount: 50)
            // TODO: parallelize with taskGroup?
            // NOTE: limit is 50
            for ids in chunkedIDs {
                do {
                    let ids = Array(ids)
                    let languageCode = Locale.current.wikiLanguageCodeIdentifier


                    // TODO: MAYBE! fetch claims (for commmonsCategory, length, etc.) in wbgetentities directly
                    // but may be less efficient in the end, because the returned json is much bigger
                    // than performing two queries like this?

                    async let wikiItemsTask = API.shared
                        .getGenericWikidataItems(itemIDs: ids, languageCode: languageCode)

                    async let labelAndDescriptionTask = API.shared
                        .fetchWikidataEntities(ids: ids, preferredLanguages: [languageCode])

                    let (WikiItems, labelAndDescription) = try await (wikiItemsTask, labelAndDescriptionTask)


                    let mergedItems: [WikidataItem] = WikiItems.map { item in
                        var item = WikidataItem(apiItem: item)
                        item.label = labelAndDescription[item.id]?.label ?? item.label
                        item.description = labelAndDescription[item.id]?.description ?? item.description
                        return item
                    }


                    do {
                        try appDatabase.upsert(mergedItems)
                    } catch {
                        logger.fault("Failed to write \(mergedItems.count) WikidataItems \(error)")
                    }

                    for item in mergedItems {
                        dictionary[item.id] = item
                        missingIDs.remove(item.id)
                    }

                } catch {
                    logger.error("Failed to fetch wikidata labels for \(self.missingIDs) \(error)")
                }
            }

        }
    }
}
