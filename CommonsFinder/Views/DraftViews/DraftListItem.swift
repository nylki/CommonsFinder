//
//  DraftListItem.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 21.01.25.
//

import CommonsAPI
import FrameUp
import GRDBQuery
import NukeUI
import SwiftUI
import os.log

struct DraftListItem: View {
    let draft: MediaFileDraft

    @Environment(Navigation.self) private var navigation
    @Environment(AccountModel.self) private var account
    @Environment(UploadManager.self) private var uploadManager
    @Environment(\.appDatabase) private var appDatabase
    @Namespace private var navigationNamespace
    @Environment(\.locale) private var locale

    @State private var isShowingDeleteDialog = false
    @State private var isShowingUploadDialog = false
    @State private var isShowingErrorSheet = false

    private func editDraft() {
        navigation.editDraft(draft: draft)
    }

    private func showDeleteDialog() {
        isShowingDeleteDialog = true
    }

    private func showUploadDialog() {
        isShowingUploadDialog = true
    }

    private func continueUpload() {
        isShowingErrorSheet = false
        if let activeUser = account.activeUser {
            try? appDatabase.updateDraft(id: draft.id, withPublishingError: nil)
            uploadManager.upload(draft, username: activeUser.username)
        }
    }


    var body: some View {
        lazy var publishingState = draft.publishingState

        let canUpload = draft.uploadPossibleStatus == .uploadPossible && account.activeUser != nil && draft.publishingState == nil
        let isPublishingCurrently = publishingState != nil && draft.publishingError == nil


        VStack {
            Button(action: editDraft) {
                imageView
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
                    .blur(radius: isPublishingCurrently ? 20 : 0)
            }
            .frame(height: 200)
            .buttonStyle(MediaCardButtonStyle())
            .overlay {
                uploadProgressOverlay
            }

            Text("Some info")
        }
        .frame(width: 200)
        .contentShape(.contextMenuPreview, .rect(cornerRadius: 18))
        .contextMenu(
            menuItems: {
                if !isPublishingCurrently {
                    if canUpload {
                        Button("Publish", systemImage: "arrowshape.up", action: showUploadDialog)
                    }
                    if draft.publishingState != .creatingWikidataClaims {
                        Button("Edit", systemImage: "pencil", action: editDraft)
                    }

                    Divider()

                    Button("Delete", systemImage: "trash", role: .destructive, action: showDeleteDialog)
                } else {
                    // TODO: show more upload info?
                }
            },
            preview: {
                imageView
            }
        )
        .disabled(isPublishingCurrently)
        .geometryGroup()
        .confirmationDialog("Are you sure you want to delete the Draft?", isPresented: $isShowingDeleteDialog, titleVisibility: .visible) {
            Button("Delete", systemImage: "trash", role: .destructive) {
                do {
                    try appDatabase.delete(draft)
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
                if let activeUser = account.activeUser {
                    uploadManager.upload(draft, username: activeUser.username)
                }
            }

            Button("Cancel", role: .cancel) {
                isShowingDeleteDialog = false
            }
        }
    }

    @ViewBuilder
    private var imageView: some View {
        let transaction = Transaction(animation: .linear)
        LazyImage(
            request: draft.localFileRequestResized,
            transaction: transaction
        ) { phase in
            ZStack {
                if draft.isDebugDraft {
                    #if DEBUG
                        Image(.debugDraft)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    #endif
                } else if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)

                } else {
                    Color.clear
                        .aspectRatio(contentMode: .fill)
                }
            }
        }
        .clipShape(.rect(cornerRadius: 16))
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)


    }

    @ViewBuilder
    private var uploadProgressOverlay: some View {

        lazy var publishingState = draft.publishingState
        lazy var publishingError = draft.publishingError

        ZStack {
            if publishingError != nil {
                errorButton
            } else if let publishingState {
                switch publishingState {
                case .uploading:
                    Text("\(Int((publishingState.uploadProgress ?? 0) * 100))%")
                        .contentTransition(.numericText(countsDown: false))
                        .font(.system(size: 40))
                        .bold()
                        .foregroundStyle(.regularMaterial)
                        .shadow(radius: 10)

                case .creatingWikidataClaims, .unstashingFile, .uploaded(filekey: _):
                    ProgressView().progressViewStyle(.circular)
                case .published:
                    Image(systemName: "checkmark.circle.fill")
                        .aspectRatio(contentMode: .fit)
                        .font(.system(size: 120))
                        .padding()
                        .foregroundStyle(.regularMaterial)
                        .transition(.blurReplace.animation(.bouncy(extraBounce: 0.2)))
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .padding()
        .clipShape(.rect(cornerRadius: 16))
        .animation(.default, value: publishingState)
        .animation(.default, value: publishingError)
        .publishingErrorDetailsSheet(
            draft.publishingState,
            draft.publishingError,
            isPresented: $isShowingErrorSheet,
            onEditDraft: editDraft,
            onDeleteDraft: showDeleteDialog,
            onContinueUpload: continueUpload
        )
    }


    private var errorButton: some View {
        Button {
            isShowingErrorSheet = true
        } label: {
            Label("upload failed", systemImage: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.hierarchical)

        }
        .transition(.blurReplace.animation(.bouncy))
        .foregroundStyle(.primary)
        .glassButtonStyle()
    }
}


#Preview(traits: .previewEnvironment) {
    ScrollView(.horizontal) {
        HStack {
            DraftListItem(draft: .makeRandomDraft(id: "1"))
            DraftListItem(draft: .makeRandomDraft(id: "2"))
            DraftListItem(draft: .makeRandomDraft(id: "3"))
        }
        .scenePadding()
    }
}
