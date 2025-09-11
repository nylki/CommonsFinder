//
//  FileCreateView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 08.10.24.
//

import Nuke
import NukeUI
import OrderedCollections
import PhotosUI
import SwiftUI
import os.log

struct FileCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UploadManager.self) private var uploadManager
    @Environment(AccountModel.self) private var account

    @State private var model: FileCreateViewModel
    @State private var isPhotosPickerPresented = false
    @State private var isFileImporterPresented = false
    @State private var isCameraPresented = false
    @State private var isInteractingWithScrollView = false

    @State private var biggerImage = false
    @State private var isShowingDeleteDialog = false
    @State private var isShowingUploadDialog = false


    /// Initializes the FileEditView with a list of files. If files are empty, start with a blank view, where users add new files.
    /// - Parameter files: [MediaFile]
    init(appDatabase: AppDatabase, files: [MediaFileDraft] = []) {
        // NOTE: It is ok to initialize the @State model in the init, as we don't expect
        // and are not interested in subsequent prop changes from the outside.
        model = FileCreateViewModel(appDatabase: appDatabase, existingDrafts: files)
    }

    /// Initializes the FileEditView with a file.
    /// - Parameter file: MediaFile
    init(appDatabase: AppDatabase, file: MediaFileDraft) {
        model = FileCreateViewModel(appDatabase: appDatabase, existingDrafts: [file])
    }

    var body: some View {
        NavigationStack {
            VStack {
                if model.fileCount == 0 {
                    VStack(spacing: 20) {
                        ContentUnavailableView("No files added", systemImage: "photo")

                        Button("Add from Photos", systemImage: "photo.badge.plus") {
                            isPhotosPickerPresented = true
                        }


                        Button("Take new Photo", systemImage: "camera") {
                            isCameraPresented = true
                        }

                        Button("Add from Files", systemImage: "folder") {
                            isFileImporterPresented = true
                        }

                        Spacer()
                    }
                    .buttonStyle(.glass)
                    .padding()

                } else if model.editedDrafts.count == 1, let selectedID = model.selectedID, let singleSelectedModel = model.editedDrafts[selectedID] {


                    MetadataEditForm(model: singleSelectedModel)
                        .safeAreaBar(edge: .top) {
                            singleImageView(model: singleSelectedModel)
                                .padding(.bottom)
                        }


                } else if model.editedDrafts.count > 1 {

                    // TODO: Design specialized batch edit where you edit the title etc. for all images
                    // then copies with enumeration (1-99) to drafts.
                    imageScrollView


                    // TODO: debounce changes to selectedID to reduce redraws of the form when swiping really fast
                    if !isInteractingWithScrollView, let selectedID = model.selectedID, let selectedModel = model.editedDrafts[selectedID] {
                        MetadataEditForm(model: selectedModel)
                            .id(selectedID)  // .id is explicitly set to allow animated transition.
                    }
                    Spacer()
                }
            }
            .animation(.easeInOut, value: isInteractingWithScrollView)
            .animation(.default, value: biggerImage)
            .fullScreenCover(isPresented: $isCameraPresented) {
                CameraImagePicker { image, metadata in
                    do {
                        try model.handleCameraImage(image, metadata: metadata)
                    } catch {
                        logger.error("Failed to handle camera input \(error)")
                    }
                }
                .ignoresSafeArea(.container)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }

                if !model.editedDrafts.isEmpty {
                    if model.draftsExistInDB {
                        ToolbarItem(placement: .destructiveAction) {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                isShowingDeleteDialog = true
                            }
                            .confirmationDialog("Are you sure you want to delete the Draft?", isPresented: $isShowingDeleteDialog, titleVisibility: .visible) {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    do {
                                        try model.deleteDrafts()
                                    } catch {
                                        logger.error("Failed to delete drafts \(error)")
                                    }
                                    dismiss()
                                }

                                Button("Cancel", role: .cancel) {
                                    isShowingDeleteDialog = false
                                }
                            }
                        }
                    }

                    ToolbarItem(placement: .automatic) {
                        Button(model.draftsExistInDB ? "Save Changes" : "Save Draft", systemImage: "square.and.arrow.down") {
                            do {
                                try model.saveAllChanges()
                                dismiss()
                            } catch {
                                logger.error("Failed to save all drafts \(error)")
                            }
                        }
                        .disabled(!model.canSafeDrafts)
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Upload") {
                            isShowingUploadDialog = true
                        }
                        .confirmationDialog("Start upload to Wikimedia Commons now?", isPresented: $isShowingUploadDialog, titleVisibility: .visible) {
                            Button("Upload", systemImage: "square.and.arrow.up") {
                                guard let username = account.activeUser?.username else {
                                    assertionFailure()
                                    return
                                }
                                do {
                                    try model.saveAllChanges()
                                    for (_, draftModel) in model.editedDrafts {
                                        uploadManager.upload(draftModel.draft, username: username)
                                    }
                                    dismiss()
                                } catch {
                                    logger.error("Failed to initiate upload \(error)")
                                }
                            }

                            Button("Cancel", role: .cancel) {
                                isShowingDeleteDialog = false
                            }
                        }
                        .disabled(model.selectedDraft?.draft.canUpload != true || !model.canSafeDrafts || account.activeUser == nil)
                    }
                }
            }
            #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif

        }
        .onChange(of: model.editedDrafts.isEmpty, initial: true) {
            // When initially adding a file, select it
            if model.selectedID == nil, !model.editedDrafts.isEmpty {
                withAnimation {
                    model.selectedID = model.editedDrafts.values.first?.id
                }
            }
        }
        .photosPicker(
            isPresented: $isPhotosPickerPresented,
            selection: $model.photosPickerSelection,
            // NOTE: For now only allow 1 image until
            // multi-upload is refined.
            maxSelectionCount: 1,
            matching: .any(of: [.images]),
            preferredItemEncoding: .compatible,
            photoLibrary: .shared()
        )
        .fileImporter(
            isPresented: $isFileImporterPresented,
            // https://commons.wikimedia.org/wiki/Commons:File_types
            allowedContentTypes: [
                .mp3, .wav, .midi,
                .svg, .png, .webP, .gif, .jpeg,
                .mpeg,
                .pdf,
                .geoJSON,
            ],
            allowsMultipleSelection: false,
            onCompletion: model.handleFileImport(result:)
        )
    }


    @ViewBuilder func singleImageView(model: MediaFileDraftModel) -> some View {
        // we only expect the model.fileItem?.fileURL, but thumburl is useful for previews
        Button {
            biggerImage.toggle()
        } label: {
            let imageRequest: ImageRequest? =
                model.temporaryFileImageRequest
                ?? model.draft.localFileRequestFull

            LazyImage(request: imageRequest) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .transition(.blurReplace)
                } else {
                    Color.clear.background(.regularMaterial)
                }
            }
            .clipShape(.rect(cornerRadius: 23))
            .frame(height: biggerImage ? 250 : 125, alignment: .top)
        }
        .buttonStyle(ImageButtonStyle())

    }


    @ViewBuilder
    private var imageScrollView: some View {
        let itemWidth: Double = 150
        let itemHeight: Double = 150

        ScrollView(.horizontal) {
            LazyHStack {
                ForEach(model.editedDrafts.values) { file in
                    let isSelected = file.id == model.selectedID
                    let imageURL: URL? = file.fileItem?.fileURL
                    let imageRequest = ImageRequest(
                        url: imageURL, processors: [.resize(height: itemHeight)]
                    )

                    LazyImage(request: imageRequest) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .transition(.blurReplace)
                        } else {
                            Color.clear.background(.regularMaterial)
                        }
                    }
                    .clipShape(.rect(cornerRadius: 15))
                    .frame(width: itemWidth)
                    .id(file.id)
                    .scrollTransition(.interactive.threshold(.visible(0.7))) { content, phase in
                        content
                            .scaleEffect(phase.isIdentity ? 1 : 0.85)
                            .blur(radius: phase.isIdentity ? 0 : 5)
                            .opacity(phase.isIdentity ? 1 : 0.5)
                    }
                    .padding(.bottom, 10)
                    .overlay(
                        alignment: .bottom,
                        content: {
                            Color.primary
                                .frame(height: 0.5)
                                .animation(.spring.delay(0.35)) {
                                    $0.opacity(isSelected ? 1 : 0)
                                }
                        })
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, itemWidth / 3)
        }
        .onScrollPhaseChange { oldPhase, newPhase in
            isInteractingWithScrollView = newPhase != .idle
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $model.selectedID, anchor: .center)
        .sensoryFeedback(.selection, trigger: model.selectedID)
        .safeAreaPadding(.horizontal, itemWidth / 2)
        .frame(height: itemHeight)
    }
}

#Preview("Empty/Initial", traits: .previewEnvironment) {
    FileCreateView(appDatabase: .populatedPreviewDatabase())
}

#Preview(
    "new File",
    traits: .previewEnvironment
) {
    FileCreateView(appDatabase: .populatedPreviewDatabase(), file: .makeRandomDraft(id: "1"))
}

#Preview(
    "editing File",
    traits: .previewEnvironment
) {
    FileCreateView(appDatabase: .populatedPreviewDatabase(), file: AppDatabase.sampleDraft)
}
#Preview("multiple Files", traits: .previewEnvironment) {
    FileCreateView(
        appDatabase: .populatedPreviewDatabase(),
        files: [
            .makeRandomDraft(id: "2"),
            .makeRandomDraft(id: "3"),
        ])
}
