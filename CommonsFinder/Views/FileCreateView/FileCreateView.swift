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
    //    @State private var isShowingDeleteDialog = false
    //    @State private var isShowingUploadDialog = false
    //    @State private var isShowingCloseConfirmationDialog = false
    //    @State private var isShowingUploadDisabledAlert = false


    /// Initializes the FileEditView with a list of files. If files are empty, start with a blank view, where users add new files.
    /// - Parameter files: [MediaFile]
    init(appDatabase: AppDatabase, newDraftOptions: NewDraftOptions? = nil, files: [MediaFileDraft] = []) {
        // NOTE: It is ok to initialize the @State model in the init, as we don't expect
        // and are not interested in subsequent prop changes from the outside.
        model = FileCreateViewModel(appDatabase: appDatabase, existingDrafts: files, newDraftOptions: newDraftOptions)
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
                    .glassButtonStyle()
                    .padding()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("close", systemImage: "xmark", action: dismiss.callAsFunction)
                        }
                    }

                } else if model.editedDrafts.count == 1, let selectedID = model.selectedID, let singleSelectedModel = model.editedDrafts[selectedID] {
                    SingleImageDraftView(model: singleSelectedModel)
                } else if model.editedDrafts.count > 1 {

                    // TODO: Design specialized batch edit where you edit the title etc. for all images
                    // then copies with enumeration (1-99) to drafts.
                    imageScrollView

                    // TODO: debounce changes to selectedID to reduce redraws of the form when swiping really fast
                    if !isInteractingWithScrollView, let selectedID = model.selectedID, let selectedModel = model.editedDrafts[selectedID] {
                        SingleImageDraftView(model: selectedModel)
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

#Preview("empty with initial tags", traits: .previewEnvironment) {
    FileCreateView(appDatabase: .populatedPreviewDatabase(), newDraftOptions: .init(tag: .init(.earth, pickedUsages: [.category, .depict])))
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
