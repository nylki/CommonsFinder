//
//  MultiDraftOverviewList.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 19.05.26.
//

import NukeUI
import SwiftUI
import TipKit

struct MultiDraftOverviewList: View {
    @Bindable var multiDraftModel: MultiDraftModel


    var body: some View {


        List {

            TipView(MultiDraftOverviewTip())

            ForEach(multiDraftModel.info.drafts) { draft in
                let sharesDescriptionWithMultiDraft =
                    draft.captionWithDesc.isEmpty
                    || draft.captionWithDesc.allSatisfy({ captionWithDesc in
                        captionWithDesc.fullDescription.isEmpty && captionWithDesc.caption.isEmpty
                    })


                VStack(alignment: .leading) {
                    BaseDraftImageView(draft: draft)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .clipShape(.rect(cornerRadius: 16))


                    if sharesDescriptionWithMultiDraft {
                        let enumeratedDescs = Array(multiDraftModel.info.multiDraft.captionWithDesc.enumerated())
                        ForEach(enumeratedDescs, id: \.element.languageCode) { item in

                            let caption = item.element.caption
                            if !caption.isEmpty {
                                Text(caption)
                                Text("caption (\(item.element.languageCode))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            let fullDescription = item.element.fullDescription
                            if !fullDescription.isEmpty {
                                // FIXME: needs binding in multi model to allow modifying individual drafts
                                // but falling back to multi desc if empty
                                Text("description (\(item.element.languageCode))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                    } else {
                        let enumeratedDescs = Array(draft.captionWithDesc.enumerated())

                        ForEach(enumeratedDescs, id: \.element.languageCode) { item in

                            let caption = item.element.caption
                            if !caption.isEmpty {

                                Text(caption)
                                Text("caption (\(item.element.languageCode))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            let fullDescription = item.element.fullDescription
                            if !fullDescription.isEmpty {
                                Text(fullDescription)
                                Text("description (\(item.element.languageCode))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                        }
                    }

                    Text("filename.jpg")
                    Text("filename")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }


        }


    }

}

#Preview {
    MultiDraftOverviewList(multiDraftModel: .init(.makeRandom(id: 1, imageCount: 5)))
}
