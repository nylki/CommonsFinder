//
//  TagLabel.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 10.04.25.
//

import FrameUp
import SwiftUI

struct TagLabel: View {
    let tag: TagItem

    @Environment(\.locale) private var locale

    private var languageCode: String {
        locale.wikiLanguageCodeIdentifier
    }


    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TagList(possibleUsages: tag.possibleUsages, usages: tag.pickedUsages)

            VStack(alignment: .leading) {
                Text(tag.label)
                    .bold()
                    .lineLimit(2)
                if let description = tag.description {
                    Text(description)
                        .font(.caption)
                        .lineLimit(3)
                }
            }
            .multilineTextAlignment(.leading)
            .frame(minWidth: 60, alignment: .leading)
            .allowsTightening(true)
            .padding(.top, 4)
            .padding([.horizontal, .bottom], 6)
            .background(.buttonBackground)
            .clipShape(
                UnevenRoundedRectangle(
                    cornerRadii: .init(bottomLeading: 15, bottomTrailing: 15, topTrailing: 15),
                    style: .continuous
                )
            )
        }
        .animation(.default, value: tag.pickedUsages)

    }


}

struct TagList: View {
    let possibleUsages: Set<TagType>
    let usages: Set<TagType>
    @ScaledMetric private var scale = 1

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                if possibleUsages.contains(.category) {
                    let isPicked = usages.contains(.category)
                    Image(systemName: "tag.circle.fill")
                        .foregroundStyle(.white, isPicked ? .category : .gray)
                        .symbolEffect(.bounce, value: isPicked)
                        .opacity(isPicked ? 1 : 0.1)

                }

                if possibleUsages.contains(.depict) {
                    let isPicked = usages.contains(.depict)
                    Image(systemName: "eye.circle.fill")
                        .foregroundStyle(.white, isPicked ? .depict : .gray)
                        .symbolEffect(.bounce, value: isPicked)
                        .opacity(isPicked ? 1 : 0.1)
                }
            }

            .padding(.top, 5)
            .padding(.horizontal, 5)
            .background(.buttonBackground)
            .clipShape(
                UnevenRoundedRectangle(cornerRadii: .init(topLeading: 12, topTrailing: 12), style: .continuous)
            )
            .font(.system(size: 20 * scale))

            roundTriangleNotch
        }

    }

    private var roundTriangleNotch: some View {
        Rectangle()
            .subtracting(
                UnevenRoundedRectangle(
                    cornerRadii: .init(bottomLeading: 12),
                    style: .continuous
                )
            )
            .fill(.buttonBackground)
            .frame(width: 8, height: 20)

    }
}

#Preview("TagList", traits: .previewEnvironment) {
    VStack {
        TagList(possibleUsages: [.category, .depict], usages: [])
        TagList(possibleUsages: [.category, .depict], usages: [.category])
        TagList(possibleUsages: [.category, .depict], usages: [.depict])
        TagList(possibleUsages: [.category, .depict], usages: [.category, .depict])

        TagList(possibleUsages: [.depict], usages: [])
        TagList(possibleUsages: [.depict], usages: [.depict])

        TagList(possibleUsages: [.category], usages: [])
        TagList(possibleUsages: [.category], usages: [.category])
    }
    .border(.red)
}

#Preview("TagLabel Animation", traits: .previewEnvironment) {
    @Previewable @State var interactiveSelection: Set<TagType> = [.category]

    VStack {
        Button("Add/Remove") {
            withAnimation(.default) {
                if interactiveSelection.isEmpty {
                    interactiveSelection.insert(.category)
                } else {
                    interactiveSelection.removeAll()
                }

            }

        }

        HFlowLayout {
            TagLabel(tag: .init(.earth, pickedUsages: []))
            TagLabel(tag: .init(.earth, pickedUsages: []))
            TagLabel(tag: .init(.earth, pickedUsages: interactiveSelection))
            TagLabel(tag: .init(.earth, pickedUsages: []))
            TagLabel(tag: .init(.earth, pickedUsages: []))
        }

    }

}


#Preview("TagLabel short", traits: .previewEnvironment) {
    TagLabel(tag: .init(.earth, pickedUsages: []))
    TagLabel(tag: .init(.earth, pickedUsages: [.depict]))
    TagLabel(tag: .init(.earth, pickedUsages: [.category]))
    TagLabel(tag: .init(.earth, pickedUsages: [.depict, .category]))
}

#Preview("TagLabel long", traits: .previewEnvironment) {
    TagLabel(tag: .init(.earthExtraLongLabel, pickedUsages: []))
    TagLabel(tag: .init(.earthExtraLongLabel, pickedUsages: [.depict]))
    TagLabel(tag: .init(.earthExtraLongLabel, pickedUsages: [.category]))
    TagLabel(tag: .init(.earthExtraLongLabel, pickedUsages: [.depict, .category]))

}
