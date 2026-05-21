//
//  MultiDraftOverviewList.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 19.05.26.
//

import NukeUI
import SwiftUI

struct MultiDraftOverviewList: View {
    @Bindable var multiDraftModel: MultiDraftModel


    var body: some View {
        let enumeratedDescs = Array(multiDraftModel.info.multiDraft.captionWithDesc.enumerated())

        List(multiDraftModel.info.drafts) { draft in

            VStack(alignment: .leading) {
                BaseDraftImageView(draft: draft)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipShape(.rect(cornerRadius: 16))

                Text(draft.name)
                    .italic()

                if draft.captionWithDesc.isEmpty {
                    ForEach(enumeratedDescs, id: \.element.languageCode) { item in

                        let caption = item.element.caption
                        if !caption.isEmpty {
                            Text(caption)
                        }

                        let fullDescription = item.element.fullDescription
                        if !fullDescription.isEmpty {
                            Text(fullDescription)
                        }

                    }
                    .foregroundStyle(.secondary)
                } else {
                    Text("customized Text")
                        .bold()
                }
            }

            .frame(height: 300)
        }

    }

}

#Preview {
    MultiDraftOverviewList(multiDraftModel: .init(.makeRandom(id: 1, imageCount: 5)))
}
