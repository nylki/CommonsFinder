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
                    NavigationLink(value: NavigationStackItem.wikidataItem(.init(tag.baseItem))) {
                        TagLabel(tag: tag)
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .groupBoxStyle(FileGroupBoxStyle())
    }
}

#Preview {
    TagsContainerView(tags: [.init(.earth, pickedUsages: [.depict])])
}
