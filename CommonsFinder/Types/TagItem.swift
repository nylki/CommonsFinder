//
//  TagItemProtocol.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 03.04.25.
//

enum TagType: Codable, Equatable, Hashable {
    case category
    case depict
    // case significantEvent
}

enum BaseTagItem: Codable, Equatable, Hashable {
    case wikidataItem(WikidataItem)
    case category(String)
}

/// combines categories, depict items and possible future statements like significant event
struct TagItem: Codable, Equatable, Hashable, Identifiable {
    let baseItem: BaseTagItem

    // TODO: add support for qualifiers (eg. depicted part)

    /// what the user has choosen to be used for (eg. as depict-statement, category or both)
    var pickedUsages: Set<TagType> = []

    init(wikidataItem: WikidataItem, pickedUsages: Set<TagType>) {
        self.baseItem = .wikidataItem(wikidataItem)
        self.pickedUsages = pickedUsages
    }

    init(category: String, isPicked: Bool) {
        self.baseItem = .category(category)
        if isPicked {
            self.pickedUsages = [.category]
        }
    }

    var id: String {
        switch baseItem {
        case .category(let category):
            category
        case .wikidataItem(let item):
            item.id
        }
    }

    /// what the user can choose this tag to be used for
    var possibleUsages: Set<TagType> {
        switch baseItem {
        case .wikidataItem(let wikidataItem):
            if wikidataItem.commonsCategory?.isEmpty == false {
                return [.depict, .category]
            } else {
                return [.depict]
            }
        case .category:
            return [.category]
        }
    }

    var label: String {
        switch baseItem {
        case .wikidataItem(let wikidataItem):
            wikidataItem.label ?? wikidataItem.commonsCategory ?? wikidataItem.id
        case .category(let category):
            category
        }
    }

    var description: String? {
        switch baseItem {
        case .wikidataItem(let wikidataItem):
            wikidataItem.description
        case .category:
            nil
        }
    }
}
