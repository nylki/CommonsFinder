//
//  TagButton.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 20.04.25.
//

import SwiftUI

struct TagButton: View {
    let tag: TagModel
    let onFocused: (Bool) -> Void

    @State private var isShowingPopover = false

    var body: some View {
        @Bindable var tag = tag


        Button(
            action: {
                isShowingPopover = true
            },
            label: {
                TagLabel(tag: tag.tagItem)
            }
        )

        .onChange(of: isShowingPopover) {
            onFocused(isShowingPopover)
        }

        .popover(isPresented: $isShowingPopover) {
            let canUseAsCategory = tag.tagItem.possibleUsages.contains(.category)
            let canUseAsDepict = tag.tagItem.possibleUsages.contains(.depict)

            VStack {
                if canUseAsCategory {
                    VStack {
                        if let category = tag.commonsCategory {
                            Text(category)
                        }
                        Toggle(isOn: $tag.tagItem.pickedUsages[contains: .category]) {
                            Text("Category")
                        }
                        .tint(.category)
                    }
                }

                if canUseAsDepict {
                    Toggle(isOn: $tag.tagItem.pickedUsages[contains: .depict]) {
                        Text("Depicted")
                    }
                    .tint(.depict)
                }
            }
            .padding()
            .toggleStyle(.switch)
            .presentationCompactAdaptation(.popover)
        }
    }
}

#Preview("TagButton Animations", traits: .previewEnvironment) {
    @Previewable @State var interactiveSelection: Set<TagType> = [.category]
    @Previewable @State var tagModels: [TagModel] = [
        .init(tagItem: .init(.earth, pickedUsages: [])),
        .init(tagItem: .init(.testItemNoDesc, pickedUsages: [])),
        .init(tagItem: .init(.testItemNoLabel, pickedUsages: [])),

    ]

    VStack {
        ForEach(tagModels, id: \.self) { tag in
            TagButton(tag: tag) { focused in }
        }
    }
    .buttonStyle(.plain)

}
