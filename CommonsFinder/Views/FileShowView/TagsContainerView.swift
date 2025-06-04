//
//  TagsContainerView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 29.03.25.
//

import Foundation
import FrameUp
import SwiftUI

struct TagsContainerView: View {

    let tags: [TagItem]

    var body: some View {
        GroupBox("Tags") {
            HFlowLayout(alignment: .leading) {
                ForEach(tags) { tag in

                    let navigationValue =
                        switch tag.baseItem {
                        case .category(let category):
                            NavigationStackItem.category(title: category)
                        case .wikidataItem(let wikiItem):
                            NavigationStackItem.wikiItem(id: wikiItem.id)
                        }

                    NavigationLink(value: navigationValue) {
                        TagLabel(tag: tag)
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
    }
}


#Preview {
    TagsContainerView(tags: [.init(wikidataItem: .earth, pickedUsages: [.depict])])
}
