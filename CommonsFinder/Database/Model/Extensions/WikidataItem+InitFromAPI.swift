//
//  WikidataItem+InitFromAPI.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 01.04.25.
//

import CommonsAPI
import Foundation

extension WikidataItem {
    init(apiItem: GenericWikidataItem) {
        self.init(
            id: apiItem.id,
            preferredLanguageAtFetchDate: apiItem.labelLanguage,
            fetchDate: .now,
            label: apiItem.label,
            description: apiItem.description,
            aliases: [],
            commonsCategory: apiItem.commonsCategory,
            instances: apiItem.instances ?? [],
            latitude: apiItem.latitude,
            longitude: apiItem.longitude,
            image: apiItem.image
        )
    }
}
