//
//  Category+InitFromAPI.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 01.04.25.
//

import CommonsAPI
import Foundation

extension Category {
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
            image: apiItem.image
        )
    }
}
