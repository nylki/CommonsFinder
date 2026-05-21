////
////  TagPickerModel.swift
////  CommonsFinder
////
////  Created by Tom Brewe on 05.12.24.
////
//
//import Algorithms
//import CommonsAPI
//import OrderedCollections
//import SwiftUI
//import os.log
//
//@Observable
//final class TagPickerModel {
//    var appDatabase: AppDatabase?
//
//    var popoverTag: TagModel?
//
//    private var _isSuggestedNearbyTagsExpanded = false
//
//    var isSuggestedNearbyTagsExpanded: Bool {
//        get {
//            _isSuggestedNearbyTagsExpanded
//        }
//        set {
//            _isSuggestedNearbyTagsExpanded = newValue
//            if newValue == false {
//                copySuggestedTags()
//            }
//        }
//    }
//
//    @ObservationIgnored
//    var searchTask: Task<Void, Never>?
//
//    var tags: OrderedSet<TagModel> = []
//
//    var searchedTags: OrderedSet<TagModel> = []
//    var suggestedNearbyTags: OrderedSet<TagModel> = []
//
//
//    var pickedTags: [TagModel] {
//        tags.filter { $0.pickedUsages.isEmpty == false }
//    }
//    var pickedCategories: [TagModel] {
//        tags.filter { $0.pickedUsages.contains(.category) }
//    }
//    var pickedDepictions: [TagModel] {
//        tags.filter { $0.pickedUsages.contains(.depict) }
//    }
//    var unPickedTags: [TagModel] {
//        tags.filter { $0.pickedUsages.isEmpty }
//    }
//
//    init(appDatabase: AppDatabase, initialTags: [TagItem], suggestedNearbyTags: [TagItem]) {
//        self.appDatabase = appDatabase
//
//        let tagModels: [TagModel] = initialTags.map { TagModel.init(tagItem: $0) }
//        tags.append(contentsOf: tagModels)
//
//        self.suggestedNearbyTags = OrderedSet(
//            suggestedNearbyTags.map { .init(tagItem: $0) }
//        )
//
//        //        let suggestedNearbyTagIDs = Set(suggestedNearbyTags.map(\.id))
//        //        let tagIDs = Set(tags.map(\.id))
//
//        // Initially show suggested nearby tags, if no tags picked yet
//        if initialTags.isEmpty {
//            _isSuggestedNearbyTagsExpanded = true
//        }
//    }
//
//    func copySuggestedTags() {
//        let pickedTags = (suggestedNearbyTags.union(searchedTags))
//            .filter {
//                $0.pickedUsages.isEmpty == false
//            }
//
//        if !pickedTags.isEmpty {
//            tags.append(contentsOf: pickedTags)
//        }
//    }
//
//
//}
