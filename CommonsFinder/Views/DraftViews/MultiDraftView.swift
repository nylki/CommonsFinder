//
//  MultiDraftView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.03.26.
//


import SwiftUI
import os.log

struct MultiDraftView: View {
    @Bindable var model: MultiDraftModel

    var body: some View {
        let showIndividualCarousel = model.multiDraft.copiedFieldsIntoSubDrafts

        if showIndividualCarousel {
            MultiDraftIndividualCarouselView(model: model)
        } else {
            MultiDraftCombinedView(model: model)
        }

    }

}


#Preview("New Draft", traits: .previewEnvironment) {
    @Previewable @State var draft = MultiDraftModel(.makeRandom(id: 1, imageCount: 5))

    MultiDraftView(model: draft)
}

#Preview("With Metadata", traits: .previewEnvironment) {
    @Previewable @State var draft = MultiDraftModel(.makeRandom(id: 1, imageCount: 5))

    MultiDraftView(model: draft)
}
