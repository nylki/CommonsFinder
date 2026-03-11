//
//  DraftSheetModifer.swift
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

struct DraftSheetModifer: ViewModifier {
    @Binding var importModel: FileImportModel?

    @State private var draftedFileModels: [MediaFileDraftModel]?


    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.dismiss) private var dismiss

    var isPhotosPickerPresented: Binding<Bool> {
        .init(
            get: {
                importModel?.isPhotosPickerPresented ?? false
            },
            set: { isPresented in
                importModel?.isPhotosPickerPresented = isPresented
            })
    }

    var photosPickerSelection: Binding<[PhotosPickerItem]> {
        .init(
            get: {
                importModel?.photosPickerSelection ?? []
            },
            set: { newValue in
                importModel?.photosPickerSelection = newValue
            })
    }

    var isFileImporterPresented: Binding<Bool> {
        .init(
            get: {
                importModel?.isFileImporterPresented ?? false
            },
            set: { newValue in
                importModel?.isFileImporterPresented = newValue
            })
    }

    var isCameraPresented: Binding<Bool> {
        .init(
            get: {
                importModel?.isCameraPresented ?? false
            },
            set: { newValue in
                importModel?.isCameraPresented = newValue
            })
    }


    func body(content: Content) -> some View {
        content
            .sheet(item: $draftedFileModels, onDismiss: { importModel = nil }) { draftedFileModels in

                NavigationStack {
                    if draftedFileModels.count == 1, let draftedFileModel = draftedFileModels.first {
                        SingleImageDraftView(model: draftedFileModel)
                    } else if draftedFileModels.count > 1 {
                        Color.red.overlay {
                            Text("Multiple files")
                        }
                    }

                }
            }
            .photosPicker(
                isPresented: isPhotosPickerPresented,
                selection: photosPickerSelection,
                // NOTE: For now only allow 1 image until
                // multi-upload is refined.
                //                maxSelectionCount: 1,
                matching: .any(of: [.images]),
                preferredItemEncoding: .compatible,
                photoLibrary: .shared()
            )
            .fileImporter(
                isPresented: isFileImporterPresented,
                // https://commons.wikimedia.org/wiki/Commons:File_types
                allowedContentTypes: [
                    //                    .mp3, .wav, .midi,
                    .svg, .png, .webP, .gif, .jpeg,
                    //                    .mpeg,
                    //                    .pdf,
                    //                    .geoJSON,
                ],
                allowsMultipleSelection: false,
                onCompletion: { result in
                    importModel?.handleFileImport(result: result)
                }
            )
            .fullScreenCover(isPresented: isCameraPresented) {
                CameraImagePicker { image, metadata in
                    do {
                        try importModel?.handleCameraImage(image, metadata: metadata)
                    } catch {
                        logger.error("Failed to handle camera input \(error)")
                    }
                }
                .ignoresSafeArea(.container)
            }
            .onChange(of: importModel?.importStatus) {
                guard let importModel, importModel.importStatus == .finished else { return }
                let fileCount = importModel.editedDrafts.count
                if fileCount == 1, let newDraftModel = importModel.editedDrafts.values.first {
                    draftedFileModels = [newDraftModel]
                } else if fileCount > 1 {
                    draftedFileModels = Array(importModel.editedDrafts.values)
                }

            }
    }
}

extension [MediaFileDraftModel]: @retroactive Identifiable {
    public var id: String {
        self.reduce("") { partialResult, next in
            partialResult + next.id
        }
    }
}
