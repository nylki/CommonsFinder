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
                maxSelectionCount: 50,
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
                let fileCount = importModel.importedItems.count
                if fileCount == 1, var fileItem = importModel.importedItems.values.first {
                    do {
                        let newDraft = try MediaFileDraft(
                            fileItem,
                            isPartOfMultiDraft: false,
                            newDraftOptions: importModel.newDraftOptions
                        )
                        navigation.editDraft(draft: newDraft)
                    } catch {
                        logger.error("Failed to create draft \(error)")
                    }
                } else if fileCount > 1 {
                    let multiDraft = MultiDraft(newDraftOptions: importModel.newDraftOptions)
                    let subDrafts: [MediaFileDraft] = importModel.importedItems.values.compactMap { fileItem in
                        do {
                            return try .init(
                                fileItem,
                                isPartOfMultiDraft: true,
                                newDraftOptions: nil
                            )
                        } catch {
                            logger.error("Failed to create draft \(error)")
                            return nil
                        }
                    }
                    let info = MultiDraftInfo(
                        multiDraft: .init(newDraftOptions: importModel.newDraftOptions),
                        drafts: subDrafts
                    )
                    navigation.editMultipleDrafts(multiDraftInfo: info)
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
