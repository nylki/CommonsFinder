//
//  MultiDraftIndividualCarouselView.swift
//  CommonsFinder
//
//  Created by Tom on 18.07.26.
//

import Foundation
import OrderedCollections
import SwiftUI
import TipKit
import os.log

struct MultiDraftIndividualCarouselView: View {
    @Bindable var model: MultiDraftModel

    @Environment(UploadManager.self) private var uploadManager
    @Environment(AccountModel.self) private var account
    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingDeleteDialog = false
    @State private var isShowingUploadDialog = false
    @State private var isShowingUploadDisabledAlert = false
    @State private var isShowingCloseConfirmationDialog = false
    @State private var isZoomableImageViewerPresented = false
    @State private var isInteractingWithScrollView = false
    @State private var selectedDraftID: MediaFileDraft.ID?
    @State private var zoomableImageReference: ZoomableImageReference?

    private var selectedDraftModel: SingleDraftModel? {
        if let selectedDraftID {
            model.subDraftModels[selectedDraftID]
        } else {
            nil
        }
    }

    var body: some View {
        VStack {
            TipView(MultiDraftIndividualCarouselTip())
                .padding()
            if !isInteractingWithScrollView, let selectedDraftModel {
                IndividualDraftForm(model: selectedDraftModel, withImage: false)
                    .id(selectedDraftID)
                    .transition(.blurReplace)
            }
            Spacer(minLength: 0)
        }
        .animation(.default, value: isInteractingWithScrollView)
        .fallbackSafeAreaBar(edge: .top) { imageScrollView }
        .navigationTitle("Draft")
        .navigationSubtitleFallback(subtitle: Text("\(model.subDraftModels.count) files"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .task {
            if selectedDraftID == nil {
                selectedDraftID = model.subDraftModels.values.first?.id
            }
        }
        .task(id: model.subDraftModels.values.map(\.draft.name)) {
            do {
                try await model.validateFilenameImpl()
            } catch {
                logger.error("Failed to validate file names \(error)")
            }
        }
    }

    private var uploadButton: some View {
        Button {
            isShowingUploadDialog = true
        } label: {
            Label("Upload", image: "custom.arrow.up.square.stack")
        }
        .confirmationDialog("Start upload to Wikimedia Commons now?", isPresented: $isShowingUploadDialog, titleVisibility: .visible) {
            Button("Upload", systemImage: "square.and.arrow.up", role: .fallbackConfirm) {
                do {
                    try model.startUpload(appDatabase: appDatabase, uploadManager: uploadManager)
                } catch {
                    // TODO: surface error to use?
                    logger.error("Failed to start upload")
                }
                dismiss()
            }

            Button("Cancel", role: .cancel) {
                isShowingDeleteDialog = false
            }
        }
    }

    private var uploadDisabledButton: some View {
        Button {
            isShowingUploadDisabledAlert = true
        } label: {
            Label("Upload", image: "custom.arrow.up.square.stack")
        }
        .tint(Color.gray.opacity(0.5))
        .alert(
            "Upload not possible", isPresented: $isShowingUploadDisabledAlert,
            actions: {
                Button("Ok") {}
            },
            message: {
                switch model.multiDraft.uploadPossibleStatus {
                case .uploadPossible:
                    Text("Unknown error, please make a screenshot and report this issue if you see this.")
                case .missingCaptionOrDescription:
                    Text("Please provide a caption or description.")
                case .missingLicense:
                    Text("You must choose the license under which you want to publish the file.")
                case .missingTags:
                    Text("You should add atleast one category or depicted item in the Tags-section.")
                case .validationError(let nameValidationError):
                    if let errorDescription = nameValidationError.errorDescription {
                        Text(errorDescription)
                    }
                    if let failureReason = nameValidationError.failureReason {
                        Text(failureReason)
                    }
                case .failedToValidate:
                    Text("There was an error validating the file name.")
                case nil:
                    Text("Currently checking if you can upload. please wait a short moment...")
                }
            })
    }

    @ViewBuilder
    private var imageScrollView: some View {
        let itemWidth: Double = 150
        let itemHeight: Double = 150

        ScrollView(.horizontal) {
            LazyHStack(spacing: 10) {
                ForEach(model.subDraftModels.values.map(\.draft)) { file in
                    let isSelected = selectedDraftID == file.id
                    Button {
                        if isSelected,
                            !isInteractingWithScrollView,
                            let imageRequest = file.imageRequest(size: .full)
                        {
                            zoomableImageReference = .localImage(.init(image: imageRequest, fullWidth: file.width, fullHeight: file.height, fullByte: nil))
                            isZoomableImageViewerPresented = true
                        } else {
                            withAnimation {
                                selectedDraftID = file.id
                            }

                        }


                    } label: {

                        BaseDraftImageView(draft: file, size: .thumb)
                            .clipShape(.rect(cornerRadius: 15))
                            .scaleEffect(isSelected ? 1 : 0.85)
                            .blur(radius: isSelected ? 0 : 5)
                            .opacity(isSelected ? 1 : 0.5)
                            .padding(.bottom, 10)


                    }
                    .frame(width: itemWidth)
                    .animation(.default, value: isSelected)


                }
            }
            .scrollTargetLayout()

        }
        .onScrollPhaseChange { oldPhase, newPhase in
            isInteractingWithScrollView = newPhase != .idle
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $selectedDraftID, anchor: .center)
        .sensoryFeedback(.selection, trigger: selectedDraftID)
        .safeAreaPadding(.horizontal, itemWidth)
        .frame(height: itemHeight)
        .zoomableImageFullscreenCover(
            imageReference: zoomableImageReference,
            isPresented: $isZoomableImageViewerPresented
        )
    }


    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {

        // FIXME: check if we can dedupe this, as it same buttons as the previous draft view
        ToolbarItem(placement: .navigation) {
            Button("Close", systemImage: "xmark", role: .fallbackClose) {
                if model.draftExistsInDB {
                    saveChangesAndDismiss()
                    dismiss()
                } else {
                    isShowingCloseConfirmationDialog = true
                }
            }
            .labelStyle(.iconOnly)
            .confirmationDialog(
                "Save draft for later or delete now?",
                isPresented: $isShowingCloseConfirmationDialog,
                titleVisibility: .visible
            ) {
                Button("Save Draft", systemImage: "square.and.arrow.down", role: .fallbackConfirm) {
                    saveChangesAndDismiss()
                }
                Button("Delete Draft", systemImage: "trash", role: .destructive) {
                    deleteDraftAndDismiss()
                }
            }
        }

        if model.draftExistsInDB {
            ToolbarItem(placement: .destructiveAction) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    isShowingDeleteDialog = true
                }
                .confirmationDialog(
                    "MULTIDRAFT DELETION CONFIRMATION FILECOUNT \(model.subDraftModels.count)",
                    isPresented: $isShowingDeleteDialog,
                    titleVisibility: .visible
                ) {
                    Button("Delete", systemImage: "trash", role: .destructive, action: deleteDraftAndDismiss)

                    Button("Cancel", role: .cancel) { isShowingDeleteDialog = false }
                }
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            if account.activeUser != nil, model.multiDraft.uploadPossibleStatus == .uploadPossible {
                uploadButton
            } else {
                uploadDisabledButton
            }
        }
    }

    private func saveChangesAndDismiss() {
        do {
            try model.saveEditingChanges(appDatabase: appDatabase)
        } catch {
            logger.error("Failed to save editing changes")
        }
        dismiss()
    }

    private func deleteDraftAndDismiss() {
        do {
            try appDatabase.delete(model.multiDraft)
            dismiss()
        } catch {
            logger.error("Failed to delete drafts \(error)")
        }
    }
}

#Preview("New Draft", traits: .previewEnvironment) {
    @Previewable @State var draft = MultiDraftModel(.makeRandom(id: 1, imageCount: 5))

    MultiDraftIndividualCarouselView(model: draft)
}

#Preview("With Metadata", traits: .previewEnvironment) {
    @Previewable @State var draft = MultiDraftModel(.makeRandom(id: 1, imageCount: 5))

    MultiDraftIndividualCarouselView(model: draft)
}
