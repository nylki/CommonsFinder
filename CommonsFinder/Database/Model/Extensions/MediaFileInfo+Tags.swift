//
//  MediaFileInfo+Tags.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 20.04.25.
//

import Algorithms
import CommonsAPI
import Foundation

extension MediaFile {
    @MainActor
    func resolveTags(appDatabase: AppDatabase) async throws -> [TagItem] {

        let depictWikdataIDs: [String] =
            statements
            .filter(\.isDepicts)
            .compactMap(\.mainItem?.id)


        let cachedCategoryInfos = (try? appDatabase.fetchCategoryInfos(wikidataIDs: depictWikdataIDs)) ?? []
        let cachedIDs = cachedCategoryInfos.compactMap(\.base.wikidataId)
        let missingIDs = Set(depictWikdataIDs).subtracting(cachedIDs)

        let fetchedMissingCategoryInfos: [CategoryInfo] = try await fetchAndCacheMissingCategory(
            appDatabase: appDatabase,
            wikidataIDs: Array(missingIDs)
        )
        .map { .init($0) }

        let groupedWikidataCategories = Set(consume cachedCategoryInfos + consume fetchedMissingCategoryInfos).grouped(by: \.base.wikidataId)

        // Make sure to continue with results in the original order
        let combinedCategoryInfos = depictWikdataIDs.compactMap { wikidataID in
            groupedWikidataCategories[wikidataID]?.first?.base
        }

        let depictionTags: [TagItem] =
            combinedCategoryInfos
            .compactMap { categoryInfo in
                var usages: Set<TagType> = [.depict]
                if let categoryName = categoryInfo.commonsCategory, categories.contains(categoryName) {
                    usages.insert(.category)
                }
                return TagItem(categoryInfo, pickedUsages: usages)
            }

        let categoriesWithDepiction: [String] =
            depictionTags
            .filter { $0.pickedUsages.contains(.category) }
            .compactMap { depictItem in
                depictItem.baseItem.commonsCategory
            }


        let pureCategoryTags: [TagItem] =
            categories
            .filter { !categoriesWithDepiction.contains($0) }
            .map { category in
                .init(Category(commonsCategory: category), pickedUsages: [.category])
            }

        return depictionTags + pureCategoryTags
    }

    private func fetchAndCacheMissingCategory(appDatabase: AppDatabase, wikidataIDs: [String]) async throws -> [Category] {

        let apiFetchLimit = 50
        let chunkedIDs = wikidataIDs.chunks(ofCount: apiFetchLimit)

        var fetchedCategories: [Category] = []
        // TODO: parallelize with taskGroup?
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

                let (wikiItems, labelAndDescription) = try await (wikiItemsTask, labelAndDescriptionTask)


                let mergedItems: [Category] = wikiItems.compactMap { apiItem in
                    var item = Category(apiItem: apiItem)
                    item.label = labelAndDescription[apiItem.id]?.label ?? item.label
                    item.description = labelAndDescription[apiItem.id]?.description ?? item.description
                    return item
                }

                fetchedCategories.append(contentsOf: mergedItems)

            }
        }

        try appDatabase.upsert(fetchedCategories)
        return fetchedCategories
    }
}
