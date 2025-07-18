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

/// combines categories, depict items and possible future statements like significant event
struct TagItem: Codable, Equatable, Hashable, Identifiable {
    let baseItem: Category

    // TODO: add support for qualifiers (eg. depicted part)

    /// what the user has choosen to be used for (eg. as depict-statement, category or both)
    var pickedUsages: Set<TagType> = []

    init(_ item: Category, pickedUsages: Set<TagType> = .init()) {
        self.baseItem = item
        self.pickedUsages = pickedUsages
    }

    var id: String {
        (baseItem.wikidataId ?? baseItem.commonsCategory)!
    }

    /// what the user can choose this tag to be used for
    var possibleUsages: Set<TagType> {
        let hasWikidataId = baseItem.wikidataId != nil
        let hasCommonsCategory = baseItem.commonsCategory?.isEmpty == false

        if hasWikidataId, hasCommonsCategory {
            return [.depict, .category]
        } else if hasWikidataId {
            return [.depict]
        } else if hasCommonsCategory {
            return [.category]
        } else {
            assertionFailure()
            return []
        }
    }

    var label: String {
        baseItem.label ?? baseItem.commonsCategory ?? baseItem.wikidataId ?? ""
    }

    var description: String? {
        baseItem.description
    }
}


extension [TagItem] {
    static var sampleTags: Self {
        [
            .init(.earth, pickedUsages: []),
            .init(.testItemNoLabel, pickedUsages: []),
            .init(.testItemNoDesc, pickedUsages: []),
            .init(.earthExtraLongLabel, pickedUsages: []),
            .init(.randomItem(id: "432"), pickedUsages: []),
            .init(.randomItem(id: "982323"), pickedUsages: []),
        ]
    }
}
