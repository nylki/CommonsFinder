//
//  DraftFileListItem.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 21.01.25.
//

import CommonsAPI
import FrameUp
import NukeUI
import SwiftUI
import os.log

struct DraftFileListItem: View {
    let draft: MediaFileDraft

    @Environment(Navigation.self) private var navigationModel
    @Environment(AccountModel.self) private var account
    @Environment(UploadManager.self) private var uploadManager
    @Environment(\.appDatabase) private var appDatabase
    @Namespace private var navigationNamespace
    @Environment(\.locale) private var locale

    @State private var isShowingDeleteDialog = false
    @State private var isShowingUploadDialog = false


    var body: some View {
        lazy var uploadStatus = uploadManager.uploadStatus[draft.id]
        let isUploading = uploadStatus != nil
        let canUpload = (account.activeUser != nil) && draft.canUpload && !isUploading

        Button {
            navigationModel.editDrafts(drafts: [draft])
        } label: {
            imageView
                .blur(radius: isUploading ? 20 : 0)
        }
        .buttonStyle(MediaCardButtonStyle())
        .matchedTransitionSource(id: draft.id, in: navigationNamespace)
        .contextMenu(
            menuItems: {
                if !isUploading {
                    Button("Publish", systemImage: "arrowshape.up") {
                        isShowingUploadDialog = true
                    }
                    .disabled(!canUpload)

                    Button("Edit", systemImage: "pencil") {
                        navigationModel.editDrafts(drafts: [draft])
                    }

                    Divider()

                    Button("Delete", systemImage: "trash", role: .destructive) {
                        isShowingDeleteDialog = true
                    }
                } else {
                    // TODO: show more upload info?
                }
            },
            preview: {
                LazyImage(request: draft.localFileRequestResized) { phase in

                    if draft.isDebugDraft {
                        #if DEBUG
                            Image(.debugDraft)
                        #endif
                    } else if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Color.clear.frame(
                            width: Double(draft.width ?? 200),
                            height: Double(draft.height ?? 200)
                        )
                    }
                }

            }
        )
        .overlay(alignment: .bottomTrailing) {
            ZStack {
                if canUpload {
                    Button("Publish", systemImage: "arrowshape.up.fill") {
                        isShowingUploadDialog = true
                    }
                } else if !isUploading {
                    Button("Edit", systemImage: "square.and.pencil") {
                        navigationModel.editDrafts(drafts: [draft])
                    }
                }
            }
            .buttonStyle(.glass)
            .padding()
        }
        .overlay {
            uploadProgressOverlay
        }
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
                    #endif
                } else if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)

                } else {
                    Color.clear
                        .frame(
                            width: Double(draft.width ?? 200),
                            height: Double(draft.height ?? 200)
                        )
                        .overlay {
                            ProgressView()
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        }

                }
            }
        }
        .clipShape(.rect(cornerRadius: 16))
        .frame(width: 200, height: 200)
    }

    @ViewBuilder
    private var uploadProgressOverlay: some View {

        lazy var uploadStatus = uploadManager.uploadStatus[draft.id]
        let disabled = account.activeUser == nil || uploadStatus != nil

        ZStack {
            if let uploadStatus {
                switch uploadStatus {
                case .uploading, .creatingWikidataClaims, .unstashingFile:
                    ProgressView(value: uploadStatus.uploadProgress, total: 1)
                case .published:
                    Label {
                        Text("Finished")
                    } icon: {
                        Image(systemName: "checkmark.circle")
                    }
                    .font(.title3)
                    .transition(.blurReplace.animation(.bouncy))

                case .uploadWarnings(let warnings):
                    Menu {
                        ForEach(warnings, id: \.description) { warning in
                            Label(
                                warning.description,
                                systemImage: "exclamationmark.triangle"
                            )
                        }
                    } label: {
                        Label("failed to upload", systemImage: "exclamationmark")
                    }
                    .transition(.blurReplace.animation(.bouncy))

                case .unspecifiedError(let description):
                    // Need to re-login?
                    Label {
                        Text(description)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                            .contentTransition(.symbolEffect)
                    }
                    .font(.title3)
                    .transition(.blurReplace.animation(.bouncy))
                case .twoFactorCodeRequired, .emailCodeRequired:
                    Label {
                        Text("Verification Code required")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                            .contentTransition(.symbolEffect)
                    }
                    .font(.title3)
                    .transition(.blurReplace.animation(.bouncy))
                case .authenticationError(let error):
                    Label {
                        Text("Authentication Error")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                            .contentTransition(.symbolEffect)
                    }
                    .font(.title3)
                    .transition(.blurReplace.animation(.bouncy))
                case .error(let error):
                    Label {
                        Text(error.errorDescription ?? error.localizedDescription)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                            .contentTransition(.symbolEffect)
                    }
                    .font(.title3)
                    .transition(.blurReplace.animation(.bouncy))
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .padding()
        .background {
            switch uploadStatus {
            case .published: Color.green.opacity(0.7)
            case .unspecifiedError, .uploadWarnings: Color.orange.opacity(0.7)
            default: Color.clear
            }
        }
        .clipShape(.rect(cornerRadius: 16))
        .animation(.default, value: uploadStatus)
        .disabled(disabled)
    }
}


struct DraftActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote)
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(Material.regular, in: Capsule())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

#Preview {
    Button(action: { print("Pressed") }) {
        Label("Press Me", systemImage: "star")
    }
    .buttonStyle(DraftActionButtonStyle())
}


#Preview("Regular Upload", traits: .previewEnvironment(uploadSimulation: .regular)) {
    LazyVStack {
        DraftFileListItem(draft: .makeRandomDraft(id: "1"))
    }
}

#Preview("Error Upload", traits: .previewEnvironment(uploadSimulation: .withErrors)) {
    LazyVStack {
        DraftFileListItem(draft: .makeRandomDraft(id: "1"))
    }
}
