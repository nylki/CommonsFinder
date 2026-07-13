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
    @Environment(\.appDatabase) private var appDatabase

    var body: some View {
        List {
            TipView(MultiDraftOverviewTip())

            ForEach(multiDraftModel.info.drafts) { draft in
                MultiDraftOverviewIndividualItem(draft: draft, multiDraftInfo: multiDraftModel.info)
            }
            .onDelete { set in
                let ids = set.compactMap { multiDraftModel.info.drafts[$0].id }
                multiDraftModel.delete(ids, appDatabase: appDatabase)
            }
        }
        .listRowSpacing(25)
        .listStyle(.automatic)
    }
}

private struct MultiDraftOverviewIndividualItem: View {
    let draft: MediaFileDraft
    let multiDraftInfo: MultiDraftInfo

    private var filename: String? {
        try? FilenameUtils.finalFilename(for: draft, in: multiDraftInfo)
    }

    private var sharesDescriptionWithMultiDraft: Bool {
        draft.captionWithDesc.isEmpty
            || draft.captionWithDesc.allSatisfy({ captionWithDesc in
                captionWithDesc.fullDescription.isEmpty && captionWithDesc.caption.isEmpty
            })
    }

    var body: some View {
        VStack(alignment: .leading) {
            BaseDraftImageView(draft: draft, size: .resized)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipShape(.rect(cornerRadius: 16))

            descriptionSection
            filenameSection
        }
        .geometryGroup()
        .compositingGroup()
    }

    @ViewBuilder
    private var descriptionSection: some View {

        let enumeratedDescs: EnumeratedSequence<[CaptionWithDescription]> =
            if sharesDescriptionWithMultiDraft {
                multiDraftInfo.multiDraft.captionWithDesc.enumerated()
            } else {
                draft.captionWithDesc.enumerated()
            }

        VStack(alignment: .leading, spacing: 20) {
            // FIXME: needs binding in multi model und a separate model to allow modifying individual drafts
            // but falling back to multi desc if empty

            ForEach(Array(enumeratedDescs), id: \.element.languageCode) { item in
                let caption = item.element.caption
                let languageCode = item.element.languageCode
                if !caption.isEmpty {
                    GroupBox {
                        Text(caption)
                    } label: {
                        Text("caption (\(languageCode))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                }

                let fullDescription = item.element.fullDescription
                if !fullDescription.isEmpty {
                    GroupBox {
                        Text(fullDescription)
                    } label: {
                        Text("description (\(item.element.languageCode))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                }
            }
        }
    }

    @ViewBuilder
    private var filenameSection: some View {
        GroupBox {
            Text(filename ?? "failed to create filename")
        } label: {
            Text("filename")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

    }
}

#Preview {
    MultiDraftOverviewList(multiDraftModel: .init(.makeRandom(id: 1, imageCount: 5)))
}
