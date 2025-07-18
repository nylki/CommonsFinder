//
//  TagModel.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 03.04.25.
//

import Foundation
import SwiftUI

@Observable @MainActor final class TagModel {
    var tagItem: TagItem

    init(tagItem: TagItem) {
        self.tagItem = tagItem
    }
}

extension TagModel: @preconcurrency Identifiable, @preconcurrency Hashable {
    var id: String { tagItem.id }
    static func == (lhs: TagModel, rhs: TagModel) -> Bool {
        lhs.tagItem == rhs.tagItem
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(tagItem)
    }

    var commonsCategory: String? {
        baseItem.commonsCategory
    }

    var baseItem: Category { tagItem.baseItem }
    var pickedUsages: Set<TagType> {
        get { tagItem.pickedUsages }
        set { tagItem.pickedUsages = newValue }
    }
}


extension Set<TagType> {
    subscript(contains el: Element) -> Bool {
        get { contains(el) }
        set {
            if newValue {
                insert(el)
            } else {
                remove(el)
            }
        }
    }
}
