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
    var body: some View {
        LazyImage(request: draft.localFileRequestResizedGridThumb, transaction: .init(animation: .linear(duration: 0.3))) { state in
            if let image = state.image {
                image
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                Image(.debugDraft)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .clipped()
    }
}

#Preview {
    BaseDraftImageView(draft: .makeRandomDraft(id: "1"))
}
