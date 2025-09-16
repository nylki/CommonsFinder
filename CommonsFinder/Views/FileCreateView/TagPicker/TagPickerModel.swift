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

@Observable
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
                let searchedCategories = try await APIUtils.searchCategories(for: searchText)

                let existingTagIDs = Set(tags.map(\.id))

                let filteredSearchedTags: [TagModel] =
                    searchedCategories.map {
                        TagModel(tagItem: .init($0))
                    }
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
