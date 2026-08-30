//
//  FileEditView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 27.01.26.
//

import CommonsAPI
import Foundation
import FrameUp
import GRDB
import OrderedCollections
import SwiftUI
import os.log

struct EditedMediaFile {
    var referenceMediaFileInfo: MediaFileInfo
    let referenceTags: [TagItem]
    var referenceCaptions: [LanguageString] { referenceMediaFileInfo.mediaFile.captions }

    var captions: [LanguageString] = []
    var tags: [TagItem] = []

    var hasBeenEdited: Bool {
        captions != referenceCaptions || tags != referenceTags

    }


    init(with mediaFileInfo: MediaFileInfo, resolvedTags: [TagItem]) {
        self.referenceMediaFileInfo = mediaFileInfo
        self.captions = mediaFileInfo.mediaFile.captions
        self.referenceTags = resolvedTags
        self.tags = resolvedTags
    }
}

struct FileEditView: View {
    let id: MediaFile.ID

    @State private var model: EditedMediaFile?
    @State private var isRefreshing = false

    @State private var isShowingFullscreenImage = false
    @State private var isShowingTagsPicker = false
    @State private var isShowingSaveConfirmationDialog = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDatabase) private var appDatabase
    @Environment(EditingManager.self) private var editingManager
    @Environment(WikimediaLanguageStore.self) private var languageStore

    private var addedLanguages: [LanguageCode] {
        model?.captions.map(\.languageCode) ?? []
    }

    private func captionBinding(for languageCode: LanguageCode) -> Binding<String> {
        if let model {
            .init(
                get: { model.captions.first(where: { $0.languageCode == languageCode })?.string ?? "" },
                set: { newValue in
                    if let idx = model.captions.firstIndex(where: { $0.languageCode == languageCode }) {
                        self.model?.captions[idx].string = newValue
                    } else {
                        self.model?.captions.append(.init(newValue, languageCode: languageCode))
                    }

                })
        } else {
            .init(get: { "" }, set: { _ in })
        }
    }

    func refreshIfNeeded() async throws {
        guard let model else { return }
        isRefreshing = true
        let timeIntervalSinceLastFetchDate = Date.now.timeIntervalSince(model.referenceMediaFileInfo.mediaFile.fetchDate)
        print("timeIntervalSinceLastFetchDate B: \(timeIntervalSinceLastFetchDate)")
        if timeIntervalSinceLastFetchDate > (10) {
            let id = model.referenceMediaFileInfo.id
            await DataAccess.refreshMediaFileFromNetwork(id: id, appDatabase: appDatabase)
        }
        isRefreshing = false
    }


    var body: some View {
        NavigationStack {
            main
                .navigationTitle("Editing")
                //                .navigationSubtitle(mediaFileInfo.mediaFile.name)
                .navigationBarTitleDisplayMode(.inline)
        }
        .task(id: id) {
            do {
                let observation = ValueObservation.tracking { db in
                    try MediaFile
                        //  required, because we update `lastViewed` above.
                        .including(optional: MediaFile.itemInteraction)
                        .filter(id: id)
                        .asRequest(of: MediaFileInfo.self)
                        .fetchOne(db)
                }

                for try await updatedMediaFileInfo in observation.values(in: appDatabase.reader) {
                    guard let updatedMediaFileInfo else { continue }
                    try Task.checkCancellation()
                    let tags = try await DataAccess.resolveTags(of: [updatedMediaFileInfo.mediaFile], appDatabase: appDatabase)
                    model = .init(with: updatedMediaFileInfo, resolvedTags: tags)
                    try await refreshIfNeeded()
                }

            } catch {
                logger.error("edit: Failed to observe MediaFileInfo changes \(error)")
            }
        }
    }

    @ViewBuilder
    private var main: some View {
        Form {
            if let model {
                MediaFileImageButton(mediaFileInfo: model.referenceMediaFileInfo, isShowingFullscreenImage: $isShowingFullscreenImage)
                    .containerRelativeFrame(.horizontal)
                    .listRowInsets(.init())
                    .listRowBackground(Color.clear)

                Text((model.referenceMediaFileInfo).mediaFile.name)
                    .font(.caption)
                    .monospaced()
                    .textSelection(.enabled)


                captionSection(captions: model.captions)
                tagsSection(tags: model.tags)

            } else {
                VStack {
                    Text("Loading newest file version...")
                    ProgressView()
                }
            }
        }
        .disabled(isRefreshing)
        .overlay {
            if isRefreshing {
                ProgressView()
            }
        }
        .interactiveDismissDisabled(model?.hasBeenEdited ?? false)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: dismiss.callAsFunction) {
                    Label("Cancel", systemImage: "xmark")
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                if let model, model.hasBeenEdited {
                    Button(role: .fallbackConfirm) {
                        isShowingSaveConfirmationDialog = true
                    } label: {
                        Label("Save Changes", systemImage: "checkmark")
                    }
                    .confirmationDialog("Publish changes?", isPresented: $isShowingSaveConfirmationDialog, titleVisibility: .visible) {
                        Button("Cancel", systemImage: "xmark", role: .cancel) {}
                        Button("Publish", systemImage: "checkmark", role: .fallbackConfirm, action: publishChangesAndDismiss)
                    }
                }
            }

        }
        .zoomableImageFullscreenCover(
            imageReference: model?.referenceMediaFileInfo.zoomableImageReference,
            isPresented: $isShowingFullscreenImage
        )
        .fullScreenCover(isPresented: $isShowingTagsPicker) {
            if let model {
                TagPicker(
                    initialTags: model.tags,
                    analysisInput: .mediaFile(model.referenceMediaFileInfo.mediaFile),
                    onEditedTags: {
                        self.model?.tags = $0
                    }
                )
            }

        }
    }


    @ViewBuilder
    private func tagsSection(tags: [TagItem]) -> some View {
        Section {
            if !tags.isEmpty {

                HFlowLayout(alignment: .leading) {
                    ForEach(tags) { tag in
                        Button {
                            isShowingTagsPicker = true
                        } label: {
                            TagLabel(tag: tag)
                        }
                        .id(tag.id)
                    }
                    .buttonStyle(.plain)
                }
                .animation(.default, value: tags)
            }

            Button(
                tags.isEmpty ? "Add" : "Edit",
                systemImage: tags.isEmpty ? "plus" : "pencil"
            ) {
                isShowingTagsPicker = true
            }
        } header: {
            Label("Tags", systemImage: "tag")
        } footer: {
            Text("Add or edit **categories** and define what the image **depicts**. More specific categories are usually preferred.")
        }
        .disabled(isRefreshing == true)
    }

    @ViewBuilder
    private func captionSection(captions: [LanguageString]) -> some View {
        Section("Captions") {
            let enumeratedCaptions = Array(captions.enumerated())

            List {
                ForEach(enumeratedCaptions, id: \.element.languageCode) { (idx, caption) in

                    let languageCode = caption.languageCode
                    let languageName = languageStore.languages[languageCode]?.description ?? languageCode

                    VStack(alignment: .leading) {
                        Menu(languageName) {
                            Text("Choose Language")
                            Divider()
                            InputLanguageButtons(disabledLanguages: addedLanguages) { selectedLanguage in
                                changeLanguageForCaptionAndDesc(old: languageCode, new: selectedLanguage.code)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                model?.captions.remove(at: idx)
                            }
                        }

                        TextField(
                            "caption",
                            text: captionBinding(for: languageCode),
                            axis: .vertical
                        )
                        .bold()
                    }
                }
                .onDelete { set in
                    model?.captions.remove(atOffsets: set)
                }

                Menu(enumeratedCaptions.count == 0 ? "Add" : "Add Language", systemImage: "plus") {
                    Text("Choose language")
                    InputLanguageButtons(
                        disabledLanguages: addedLanguages,
                        onSelect: { addLanguage(code: $0.code) }
                    )
                }
            }
            .disabled(isRefreshing == true)
        }
    }

    private func addLanguage(code: LanguageCode) {
        guard !addedLanguages.contains(code) else {
            assertionFailure("We expect the language code to not exist yet")
            return
        }

        withAnimation {
            model?.captions.append(.init("", languageCode: code))
        }
    }


    private func changeLanguageForCaptionAndDesc(old: LanguageCode, new: LanguageCode) {
        // dont change language if same, or if the new language already exists
        // this is an assertion failure, as these actions should be disabled in the UI above.

        guard old != new, !addedLanguages.contains(new) else {
            assertionFailure()
            return
        }

        guard let oldIdx = model?.captions.firstIndex(where: { $0.languageCode == old }) else {
            return
        }

        self.model?.captions[oldIdx].languageCode = new
    }

    private func publishChangesAndDismiss() {
        guard let model else { return }
        Task<Void, Never> {
            do {
                try await editingManager.startPublishChanges(of: model)
                dismiss()
            } catch {
                logger.error("Failed to start publishing edit changes \(error)")
                dismiss()
            }
        }

    }
}


#Preview(traits: .previewEnvironment) {
    FileEditView(id: "12")
}
