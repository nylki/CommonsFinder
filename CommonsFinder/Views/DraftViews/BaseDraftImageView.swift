//
//  BaseDraftImageView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 19.05.26.
//

import NukeUI
import SwiftUI

struct BaseDraftImageView: View {
    let draft: MediaFileDraft
    let size: DraftImageSize

    var body: some View {
        LazyImage(
            request: draft.imageRequest(size: size),
            transaction: .init(animation: .linear(duration: 0.3))
        ) { state in
            if let image = state.image {
                image
                    .resizable()
                    .aspectRatio(draft.aspectRatio, contentMode: .fill)
            } else if draft.isDebugDraft {
                #if DEBUG
                    Image(.debugDraft)
                        .resizable()
                        .aspectRatio(draft.aspectRatio, contentMode: .fill)
                #endif
            } else {
                Color.clear
                    .aspectRatio(draft.aspectRatio, contentMode: .fill)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .clipped()
    }
}

#Preview("thumb") {
    BaseDraftImageView(draft: .makeRandomDraft(id: "1"), size: .thumb)
}

#Preview("resized") {
    BaseDraftImageView(draft: .makeRandomDraft(id: "2"), size: .resized)
}

#Preview("full") {
    BaseDraftImageView(draft: .makeRandomDraft(id: "3"), size: .full)
}
