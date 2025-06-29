//
//  MediaFileInfo+Tags.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 20.04.25.
//

import CommonsAPI
import Foundation

extension MediaFile {
    @MainActor
    func getTags(wikidataCache: WikidataCache) -> [TagItem] {
        let depictionTags: [TagItem] =
            statements
            .filter(\.isDepicts)
            .compactMap { claim in
                if let id = claim.mainItem?.id, let wikidataItem = wikidataCache[id] {
                    var usages: Set<TagType> = [.depict]
                    if let category = wikidataItem.commonsCategory, categories.contains(category) {
                        usages.insert(.category)
                    }

                    return TagItem(wikidataItem: wikidataItem, pickedUsages: usages)
                } else {
                    return nil
                }
            }

        let categoriesWithDepiction: [String] =
            depictionTags
            .filter { $0.pickedUsages.contains(.category) }
            .compactMap { depictItem in
                if case .wikidataItem(let wikidataItem) = depictItem.baseItem {
                    return wikidataItem.commonsCategory
                }
                return nil
            }


        let pureCategoryTags: [TagItem] =
            categories
            .filter { !categoriesWithDepiction.contains($0) }
            .map { category in
                .init(category: category, isPicked: true)
            }

        return depictionTags + pureCategoryTags
    }
}
