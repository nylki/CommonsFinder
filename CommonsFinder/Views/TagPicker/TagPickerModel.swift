//
//  TagPickerModel.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 05.12.24.
//

import Algorithms
import CommonsAPI
import OrderedCollections
import SwiftUI
import os.log

@Observable @MainActor
final class TagPickerModel {
    var searchText = ""
    var isSearching = false
    var wikidataCache: WikidataCache?

    var popoverTag: TagModel?

    @ObservationIgnored
    var searchTask: Task<Void, Never>?

    var tags: OrderedSet<TagModel> = []
    var pickedTags: [TagModel] {
        tags.filter { $0.pickedUsages.isEmpty == false }
    }
    var pickedCategories: [TagModel] {
        tags.filter { $0.pickedUsages.contains(.category) }
    }
    var pickedDepictions: [TagModel] {
        tags.filter { $0.pickedUsages.contains(.depict) }
    }
    var unPickedTags: [TagModel] {
        tags.filter { $0.pickedUsages.isEmpty }
    }


    var combinedItems: [TagModel] {
        Array(tags)  //(pickedTags + unPickedTags)
    }

    func search() {
        tags.removeAll(where: \.pickedUsages.isEmpty)
        guard !searchText.isEmpty else { return }
        guard let wikidataCache else {
            assertionFailure("We expect the wikidataCache to be initialized by now")
            return
        }

        isSearching = true
        defer { isSearching = false }

        searchTask?.cancel()
        searchTask = Task<Void, Never> {
            do {
                try await Task.sleep(for: .milliseconds(500))
                print("preferred languages: \(Locale.preferredLanguages)")
                let languageCode = Locale.current.language.languageCode?.identifier ?? "en"

                async let wikidataSearchTask = try await API.shared
                    .searchWikidataItems(term: searchText, languageCode: languageCode)
                async let categorySearchTask = try await API.shared
                    .searchCategories(term: searchText, limit: .count(50))

                let (searchItems, searchCategories) = try await (wikidataSearchTask, categorySearchTask)


                // Since the searched wikidata items don not contain all info we need (ie. commons category)
                // we fetch more detailed info and merge them.
                // NOTE: We don't simply map the items from `getGenericWikidataItems` because the labels/descriptions
                // from the action-API are preferred due to their language-fallback, which can't easily accomplished
                // with sparql queries.
                // TODO: Alternatively, we could fetch wbgetentities and use the claims to get the commons category, but might be slower than SPARQL??

                async let resolvedWikiItemsTask = API.shared
                    .getGenericWikidataItems(itemIDs: searchItems.map(\.id), languageCode: languageCode)

                /// categories often have associated wikidataItems( & vice-versa, see above), resolve wiki items for the found categories:
                async let resolvedCategoryItemsTask = API.shared
                    .findWikidataItemsForCategories(searchCategories, languageCode: languageCode)

                let (resolvedWikiItems, resolvedCategoryItems) = try await (resolvedWikiItemsTask, resolvedCategoryItemsTask)

                // We need to sort our resolved items along the original search order
                // because they arrive sorted by relevance, and we want the most relevant on top/first.
                let sortedWikiItems = searchItems.compactMap { searchItem in
                    resolvedWikiItems.first(where: { $0.id == searchItem.id })
                }
                let sortedCategoryItems = searchCategories.compactMap { category in
                    resolvedCategoryItems.first(where: { $0.commonsCategory == category })
                }

                // Prefer label and description from action API (because of language fallback):
                let labelAndDescription = searchItems.grouped(by: \.id)
                let combinedWikidataItems = (sortedWikiItems + sortedCategoryItems).uniqued(on: \.id)

                let mergedSearchWikiItems: [WikidataItem] = combinedWikidataItems.map { item in
                    var item = WikidataItem(apiItem: item)
                    item.label = labelAndDescription[item.id]?.first?.label ?? item.label
                    item.description = labelAndDescription[item.id]?.first?.description ?? item.description
                    return item
                }


                for item in mergedSearchWikiItems {
                    wikidataCache.cache(wikidataItem: item)
                }

                let wikiItemTags: [TagModel] = mergedSearchWikiItems.compactMap { item in
                    .init(tagItem: .init(wikidataItem: item, pickedUsages: []))
                }

                // Only keep categories that do not already have a wikidata item
                let categoryTags: [TagModel] = searchCategories.compactMap { category in
                    let isAlreadyInWikiItems = wikiItemTags.contains(where: { $0.category == category })
                    if isAlreadyInWikiItems { return nil }
                    return .init(tagItem: .init(category: category, isPicked: false))
                }

                let existingTagIDs = Set(tags.map(\.id))

                let filteredSearchedTags = (wikiItemTags + categoryTags)
                    .filter { searchTag in
                        !existingTagIDs.contains(searchTag.id)
                    }

                tags.append(contentsOf: filteredSearchedTags)

            } catch is CancellationError {
                // retry XCode 16.2: Apparently preview crashes when using Logger()?
                //                logger.debug("category search cancelled (debounced)")
            } catch {
                logger.error("wikidata item (tags) search error \(error)")
            }
        }
    }
}
