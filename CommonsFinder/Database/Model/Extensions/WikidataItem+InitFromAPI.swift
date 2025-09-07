//
//  Category+InitFromAPI.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 01.04.25.
//

import CommonsAPI
import Foundation

nonisolated extension Category {
    init(apiItem: GenericWikidataItem) {
        self.init(
            wikidataId: apiItem.id,
            commonsCategory: apiItem.commonsCategory,
            preferredLanguageAtFetchDate: apiItem.labelLanguage,
            fetchDate: .now,
            label: apiItem.label,
            description: apiItem.description,
            aliases: [],
            instances: apiItem.instances ?? [],
            latitude: apiItem.latitude,
            longitude: apiItem.longitude,
            areaSqm: apiItem.area,
            image: apiItem.image
        )
    }

    /// initializes an empty Category that just redirects to another
    init(wikidataID: WikidataID, redirectsTo redirectID: WikidataID) {
        self.init(
            wikidataId: wikidataID,
            commonsCategory: nil,
            redirectsToWikidataID: redirectID,
            preferredLanguageAtFetchDate: "en",
            fetchDate: .now,
            label: nil,
            description: nil,
            aliases: [],
            instances: [],
            latitude: nil,
            longitude: nil,
            areaSqm: nil,
            image: nil
        )
    }
}
