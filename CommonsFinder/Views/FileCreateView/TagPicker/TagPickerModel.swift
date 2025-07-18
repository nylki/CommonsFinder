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

    private var _searchText = ""
    var isSearching = false
    var appDatabase: AppDatabase?

    var popoverTag: TagModel?

    private var _isSuggestedNearbyTagsExpanded = false

    var isSuggestedNearbyTagsExpanded: Bool {
        get {
            _isSuggestedNearbyTagsExpanded
        }
        set {
            _isSuggestedNearbyTagsExpanded = newValue
            if newValue == false {
                copySuggestedTags()
            }
        }
    }

    @ObservationIgnored
    var searchTask: Task<Void, Never>?

    var tags: OrderedSet<TagModel> = []

    var searchedTags: OrderedSet<TagModel> = []
    var suggestedNearbyTags: OrderedSet<TagModel> = []


    var searchText: String {
        set {
            guard newValue != _searchText else { return }
            _searchText = newValue
            search()
        }
        get {
            _searchText
        }
    }

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

    init(appDatabase: AppDatabase, initialTags: [TagItem], suggestedNearbyTags: [TagItem]) {
        self.appDatabase = appDatabase

        let tagModels: [TagModel] = initialTags.map { TagModel.init(tagItem: $0) }
        tags.append(contentsOf: tagModels)

        self.suggestedNearbyTags = OrderedSet(
            suggestedNearbyTags.map { .init(tagItem: $0) }
        )

        //        let suggestedNearbyTagIDs = Set(suggestedNearbyTags.map(\.id))
        //        let tagIDs = Set(tags.map(\.id))

        // Initially show suggested nearby tags, if no tags picked yet
        if initialTags.isEmpty {
            _isSuggestedNearbyTagsExpanded = true
        }
    }

    func copySuggestedTags() {
        let pickedTags = (suggestedNearbyTags.union(searchedTags))
            .filter {
                $0.pickedUsages.isEmpty == false
            }

        if !pickedTags.isEmpty {
            tags.append(contentsOf: pickedTags)
        }
    }

    private func search() {
        tags.removeAll(where: \.pickedUsages.isEmpty)
        searchedTags.removeAll()

        copySuggestedTags()

        guard !searchText.isEmpty else { return }
        guard let appDatabase else {
            assertionFailure("We expect the appDatabase to be initialized by now")
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
                // NOTE: We don't simply map the items from `fetchGenericWikidataItems` because the labels/descriptions
                // from the action-API are preferred due to their language-fallback, which can't easily accomplished
                // with sparql queries.
                // TODO: Alternatively, we could fetch wbgetentities and use the claims to get the commons category, but might be slower than SPARQL??

                async let resolvedWikiItemsTask = API.shared
                    .fetchGenericWikidataItems(itemIDs: searchItems.map(\.id), languageCode: languageCode)

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

                let mergedSearchWikiItems: [Category] = combinedWikidataItems.map { apiItem in
                    var item = Category(apiItem: apiItem)
                    item.label = labelAndDescription[apiItem.id]?.first?.label ?? item.label
                    item.description = labelAndDescription[apiItem.id]?.first?.description ?? item.description
                    return item
                }

                do {
                    try appDatabase.upsert(mergedSearchWikiItems)
                } catch {
                    logger.error("Failed to save Category items from TagPicker during search. \(error)")
                }

                let wikiItemTags: [TagModel] = mergedSearchWikiItems.compactMap { item in
                    .init(tagItem: .init(item, pickedUsages: []))
                }

                // Only keep categories that do not already have a wikidata item
                let categoryTags: [TagModel] = searchCategories.compactMap { categoryName in
                    let isAlreadyInWikiItems = wikiItemTags.contains(where: { $0.commonsCategory == categoryName })
                    if isAlreadyInWikiItems { return nil }
                    return .init(tagItem: .init(Category(commonsCategory: categoryName), pickedUsages: []))
                }

                let existingTagIDs = Set(tags.map(\.id))

                let filteredSearchedTags = (wikiItemTags + categoryTags)
                    .filter { searchTag in
                        !existingTagIDs.contains(searchTag.id)
                    }

                searchedTags.append(contentsOf: filteredSearchedTags)

            } catch is CancellationError {
                // retry XCode 16.2: Apparently preview crashes when using Logger()?
                //                logger.debug("category search cancelled (debounced)")
            } catch {
                logger.error("wikidata item (tags) search error \(error)")
            }
        }
    }
}
