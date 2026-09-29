//
//  ImportFilesModifer.swift
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

struct ImportFilesModifer: ViewModifier {
    @Binding var importModel: FileImportModel?

    @Environment(Navigation.self) private var navigation
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
            .photosPicker(
                isPresented: isPhotosPickerPresented,
                selection: photosPickerSelection,
                maxSelectionCount: 10,
                selectionBehavior: .ordered,
                matching: .any(of: [.images]),
                // `.compatible` is what converts images to jpeg files
                preferredItemEncoding: .compatible,
                photoLibrary: .shared()
            )
            .fileImporter(
                isPresented: isFileImporterPresented,
                // https://commons.wikimedia.org/wiki/Commons:File_types
                allowedContentTypes: [
                    //                    .mp3, .wav, .midi,
                    .png, .webP, .gif, .jpeg,
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
                guard let importStatus = importModel?.importStatus else { return }

                switch importStatus {
                case .importing:
                    return
                case .finished(let result):
                    switch result {
                    case .single(let draft):
                        navigation.editDraft(draft: draft)
                    case .multi(let multiDraftInfo):
                        navigation.editMultipleDrafts(multiDraftInfo: multiDraftInfo)
                    case .empty:
                        // TODO: maybe show an error dialog that import failed
                        break
                    }
                }
            }
            .modifier(
                FileImportProgressOverlayModifier(
                    options: importModel?.fileImporterOverlayOptions,
                    onCancel: { importModel?.onFileImportCancel() }
                ))
    }
}

extension [SingleDraftModel]: @retroactive Identifiable {
    public var id: String {
        self.reduce("") { partialResult, next in
            partialResult + next.id
        }
    }
}
