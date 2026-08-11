//
//  MultiDraftTeaser.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 07.05.26.
//


import NukeUI
import SwiftUI
import os.log

struct MultiDraftTeaser: View {
    let multiDraftInfo: MultiDraftInfo

    @Environment(Navigation.self) private var navigation
    @Environment(AccountModel.self) private var account
    @Environment(UploadManager.self) private var uploadManager
    @Environment(\.appDatabase) private var appDatabase
    @Namespace private var navigationNamespace
    @Environment(\.locale) private var locale

    @State private var isShowingDeleteDialog = false
    @State private var isShowingUploadDialog = false
    @State private var isShowingStatusSheet = false


    private var rowCount: Int {
        (multiDraftInfo.drafts.count == 2) ? 1 : 2
    }
    private var rows: [GridItem] {
        return (0..<rowCount).map { _ in GridItem() }
    }

    private func editDraft() {
        isShowingStatusSheet = false
        navigation.editMultipleDrafts(multiDraftInfo: multiDraftInfo)
    }

    private func showDeleteDialog() {
        isShowingDeleteDialog = true
    }

    private func showUploadDialog() {
        isShowingUploadDialog = true
    }

    private func continueUpload() {
        guard let id = multiDraftInfo.id else {
            logger.error("No multidraft id")
            return
        }
        uploadManager.upload(multiDraftWithID: id)
    }

    private var publishingState: MultiDraft.PublishingState? {
        multiDraftInfo.multiDraft.publishingState
    }

    private var isPublishingCurrently: Bool {
        publishingState != nil
    }

    private var hasDraftsWithError: Bool {
        multiDraftInfo.drafts.allSatisfy({ $0.publishingError == nil }) == false
    }

    private var canUpload: Bool {
        guard publishingState == nil else {
            return false
        }
        return multiDraftInfo.multiDraft.uploadPossibleStatus == .uploadPossible && account.activeUser != nil && multiDraftInfo.multiDraft.publishingState == nil
    }


    private var statusLine: AttributedString? {
        guard let publishingState else {
            return nil
        }


        if publishingState.isFinished {
            var attributedString = AttributedString("\(multiDraftInfo.publishingSuccessUploadCount) uploaded")

            attributedString.foregroundColor = .completed


            if multiDraftInfo.publishingErrorUploadCount >= 1 {
                var errorString = AttributedString(" · \(multiDraftInfo.publishingErrorUploadCount) failed")
                errorString.foregroundColor = .red
                attributedString.append(errorString)
            }

            return attributedString
        } else {
            var attributedString = AttributedString("\(publishingState.completedCount + 1) of \(publishingState.totalCount)")

            attributedString.foregroundColor = .completed


            if multiDraftInfo.publishingErrorUploadCount >= 1 {
                var errorString = AttributedString(" · \(multiDraftInfo.publishingErrorUploadCount) failed")
                errorString.foregroundColor = .red
                attributedString.append(errorString)
            }

            return attributedString
        }


    }


    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            imageGridButton
                .overlay(alignment: .bottomTrailing) {
                    ZStack {
                        if canUpload {
                            Button("Publish", systemImage: "arrowshape.up.fill", action: showUploadDialog)
                        } else if publishingState == nil {
                            Button("Edit", systemImage: "square.and.pencil", action: editDraft)
                        }
                    }
                    .glassButtonStyle()
                    .padding()
                }
                .overlay {
                    if let publishingState {
                        uploadProgressOverlay(publishingState: publishingState)
                    }
                }
            info
        }
        .contentShape(.contextMenuPreview, .rect(cornerRadius: 18))
        .frame(width: 200)
        .geometryGroup()
        .contextMenu(
            menuItems: {
                if publishingState == nil {
                    if canUpload {
                        Button("Publish", systemImage: "arrowshape.up", action: showUploadDialog)
                    }
                    //                    if draft.publishingState != .creatingWikidataClaims {
                    Button("Edit", systemImage: "pencil", action: editDraft)
                    //                    }

                    Divider()

                    Button("Delete", systemImage: "trash", role: .destructive, action: showDeleteDialog)
                } else {
                    // TODO: show more upload info?
                }
            },
            preview: {
                VStack {
                    imageGridButton
                    info
                }
                .padding()
            }
        )
        .confirmationDialog("Are you sure you want to delete the Draft?", isPresented: $isShowingDeleteDialog, titleVisibility: .visible) {
            Button("Delete", systemImage: "trash", role: .destructive) {
                do {
                    try appDatabase.delete(multiDraftInfo)
                } catch {
                    logger.error("Failed to delete drafts \(error)")
                }
            }

            Button("Cancel", role: .cancel) {
                isShowingDeleteDialog = false
            }
        }
        .confirmationDialog("Start upload to Wikimedia Commons now?", isPresented: $isShowingUploadDialog, titleVisibility: .visible) {
            Button("Upload", systemImage: "square.and.arrow.up") {
                if account.activeUser != nil {
                    uploadManager.upload(multiDraftInfo)
                }
            }

            Button("Cancel", role: .cancel) {
                isShowingDeleteDialog = false
            }
        }
    }


    @ViewBuilder
    private var imageGridButton: some View {
        Button {
            if !isPublishingCurrently {
                navigation.editMultipleDrafts(multiDraftInfo: multiDraftInfo)
            }
        } label: {
            imageGrid
                .frame(width: 200, height: 200)
                .background(Color.cardBackground)
                .blur(radius: (publishingState != nil) ? 20 : 0)
        }
        .clipped()
        .buttonStyle(MediaCardButtonStyle())
    }

    private var info: some View {
        DraftTeaserInfoView(
            name: multiDraftInfo.multiDraft.name,
            statusLine: statusLine,
            combinedFileSizeInByte: multiDraftInfo.combinedFileSizeInByte,
            count: multiDraftInfo.drafts.count
        )
        .multilineTextAlignment(.leading)
        .padding(.horizontal, 5)
    }

    @ViewBuilder
    private var imageGrid: some View {
        let draftCount = multiDraftInfo.drafts.count
        let spacing = 3.0

        Group {
            switch draftCount {
            case 0, 1:
                EmptyView()
            case 2:
                HStack(spacing: spacing) {
                    ForEach(multiDraftInfo.drafts[0...1]) { draft in
                        BaseDraftImageView(draft: draft, size: .thumb)
                    }
                }

            case 3:
                HStack(spacing: spacing) {
                    BaseDraftImageView(draft: multiDraftInfo.drafts[0], size: .thumb)
                        .containerRelativeFrame(.horizontal, count: 2, spacing: 5)

                    VStack(spacing: spacing) {
                        ForEach(multiDraftInfo.drafts[1...2]) { draft in
                            BaseDraftImageView(draft: draft, size: .thumb)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .containerRelativeFrame(.horizontal, count: 2, spacing: 5)
                }

            default:
                Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
                    GridRow {
                        ForEach(multiDraftInfo.drafts[0...1]) { draft in
                            BaseDraftImageView(draft: draft, size: .thumb)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    GridRow {
                        ForEach(multiDraftInfo.drafts[2...3]) { draft in
                            BaseDraftImageView(draft: draft, size: .thumb)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }

            }
        }
    }

    @ViewBuilder
    private func uploadProgressOverlay(publishingState: MultiDraft.PublishingState) -> some View {

        ZStack {
            if publishingState.isFinished,
                multiDraftInfo.publishingErrorUploadCount >= 1
            {
                errorButton
            } else if !publishingState.isFinished {
                Button {
                    isShowingStatusSheet = true
                } label: {
                    Text("\(Int(publishingState.overallProgress * 100))%")
                        .contentTransition(.numericText(countsDown: false))
                        .font(.system(size: 40))
                        .bold()
                        .foregroundStyle(.regularMaterial)
                        .shadow(radius: 10)
                }


            } else if publishingState.isFinished, multiDraftInfo.publishingErrorUploadCount == 0 {
                Image(systemName: "checkmark.circle.fill")
                    .aspectRatio(contentMode: .fit)
                    .font(.system(size: 120))
                    .padding()
                    .foregroundStyle(.regularMaterial)
                    .transition(.blurReplace.animation(.bouncy(extraBounce: 0.2)))
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .padding()
        .clipShape(.rect(cornerRadius: 16))
        .animation(.default, value: publishingState)
        .multiDraftStatusSheet(
            id: multiDraftInfo.id,
            isPresented: $isShowingStatusSheet,
            onEditDraft: editDraft,
            onDeleteDraft: showDeleteDialog,
            onContinueUpload: continueUpload
        )
    }

    @ViewBuilder
    private var errorButton: some View {
        Button {
            isShowingStatusSheet = true
        } label: {
            Label("show errors", systemImage: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.hierarchical)
        }
        .transition(.blurReplace.animation(.bouncy))
        .foregroundStyle(.primary)
        .glassButtonStyle()
    }
}

#Preview(traits: .previewEnvironment) {
    ScrollView(.horizontal) {
        LazyVGrid(columns: [.init(), .init()], alignment: .center, spacing: 5) {

            Group {
                MultiDraftTeaser(multiDraftInfo: .makeRandom(id: 1, imageCount: 2))

                MultiDraftTeaser(multiDraftInfo: .makeRandom(id: 2, imageCount: 3))

                MultiDraftTeaser(multiDraftInfo: .makeRandom(id: 3, imageCount: 4))

                MultiDraftTeaser(multiDraftInfo: .makeRandom(id: 4, imageCount: 51))
            }


        }
        .padding()

    }
    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)


}
