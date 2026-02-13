//
//  FileEditView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 27.01.26.
//

import CommonsAPI
import Foundation
import FrameUp
import OrderedCollections
import SwiftUI
import os.log

@Observable final class EditedMediaFile {

    let referenceMediaFileInfo: MediaFileInfo
    let referenceTags: [TagItem]
    var referenceCaptions: [LanguageString] { referenceMediaFileInfo.mediaFile.captions }

    var captions: [LanguageString] = []
    var tags: [TagItem] = []

    var hasBeenEdited: Bool {
        captions != referenceCaptions || tags != referenceTags

    }

    func captionBinding(for languageCode: LanguageCode) -> Binding<String> {
        .init(
            get: { self.captions.first(where: { $0.languageCode == languageCode })?.string ?? "" },
            set: { newValue in
                if let idx = self.captions.firstIndex(where: { $0.languageCode == languageCode }) {
                    self.captions[idx].string = newValue
                } else {
                    self.captions.append(.init(newValue, languageCode: languageCode))
                }

            })
    }

    init(with mediaFileInfo: MediaFileInfo, withAppDatabase appDatabase: AppDatabase) async throws {
        self.referenceMediaFileInfo = mediaFileInfo
        self.captions = mediaFileInfo.mediaFile.captions

        let resolvedTags = try await mediaFileInfo.mediaFile.resolveTags(appDatabase: appDatabase, forceNetworkRefresh: true)
        self.referenceTags = resolvedTags
        self.tags = resolvedTags
    }
}

struct FileEditView: View {
    let mediaFileInfo: MediaFileInfo
    let resolvedTags: [TagItem]

    @State private var model: EditedMediaFile?

    @State private var isShowingFullscreenImage = false
    @State private var isShowingTagsPicker = false
    @State private var isShowingSaveConfirmationDialog = false
    @State private var nearbyCategories: [Category]? = nil
    @State private var isLoadingSuggestedTags = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDatabase) private var appDatabase
    @Environment(EditingManager.self) private var editingManager

    private var addedLanguages: [LanguageCode] {
        model?.captions.map(\.languageCode) ?? mediaFileInfo.mediaFile.captions.map(\.languageCode)
    }


    var body: some View {
        NavigationStack {
            main
                .navigationTitle("Editing")
                //                .navigationSubtitle(mediaFileInfo.mediaFile.name)
                .navigationBarTitleDisplayMode(.inline)
        }
        .task(id: mediaFileInfo) {
            guard model == nil else { return }
            do {
                model = try await .init(with: mediaFileInfo, withAppDatabase: appDatabase)
            } catch {
                // TODO: show an error!
                logger.error("failed to init edit model \(error)")
            }

        }
        .task(id: "AnalyzingImage", priority: .medium) {
            isLoadingSuggestedTags = true
            let result = await ImageAnalysis.analyze(mediaFile: mediaFileInfo.mediaFile, appDatabase: appDatabase)
            if let result {
                nearbyCategories = result.nearbyCategories
            } else {
                nearbyCategories = []
            }
            isLoadingSuggestedTags = false
        }
    }

    @ViewBuilder
    private var main: some View {
        Form {
            //            Text("isLoading: \(isLoadingSuggestedTags ? "true" : "false")")
            //            Text("Suggested: \(nearbyCategories?.count ?? -1)")
            MediaFileImageButton(mediaFileInfo: model?.referenceMediaFileInfo ?? mediaFileInfo, isShowingFullscreenImage: $isShowingFullscreenImage)
                .containerRelativeFrame(.horizontal)
                .listRowInsets(.init())
                .listRowBackground(Color.clear)

            Text((model?.referenceMediaFileInfo ?? mediaFileInfo).mediaFile.name)
                .font(.caption)
                .monospaced()
                .textSelection(.enabled)

            captionSection
            tagsSection
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
            imageReference: (model?.referenceMediaFileInfo ?? mediaFileInfo).zoomableImageReference,
            isPresented: $isShowingFullscreenImage
        )
        .fullScreenCover(isPresented: $isShowingTagsPicker) {
            TagPicker(
                initialTags: model?.tags ?? resolvedTags,
                suggestedCategories: nearbyCategories ?? [],
                isLoadingSuggestedTags: isLoadingSuggestedTags,
                onEditedTags: {
                    model?.tags = $0
                }
            )
        }
    }


    @ViewBuilder
    private var tagsSection: some View {
        Section {
            let tags: [TagItem] = model?.tags ?? resolvedTags
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

    }

    @ViewBuilder
    private var captionSection: some View {
        Section("Captions") {
            let captions = model?.captions ?? mediaFileInfo.mediaFile.captions
            let enumeratedCaptions = Array(captions.enumerated())

            List {
                ForEach(enumeratedCaptions, id: \.element.languageCode) { (idx, caption) in
                    let languageCode = caption.languageCode

                    VStack(alignment: .leading) {
                        Menu(WikimediaLanguage(code: languageCode).localizedDescription) {
                            Text("Choose Language")
                            Divider()
                            LanguageButtons(disabledLanguages: addedLanguages) { selectedLanguage in
                                changeLanguageForCaptionAndDesc(old: languageCode, new: selectedLanguage.code)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                model?.captions.remove(at: idx)
                            }
                        }
                        if let model {
                            @Bindable var model = model

                            TextField(
                                "caption",
                                text: model.captionBinding(for: languageCode),
                                axis: .vertical
                            )
                            .bold()
                        }
                    }
                }
                .onDelete { set in
                    model?.captions.remove(atOffsets: set)
                }

                Menu("Add", systemImage: "plus") {
                    Text("Choose language")
                    LanguageButtons(
                        disabledLanguages: addedLanguages,
                        onSelect: { addLanguage(code: $0.code) }
                    )
                }
            }
            .disabled(model == nil)
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

        guard let model else { return }
        guard old != new, !addedLanguages.contains(new) else {
            assertionFailure()
            return
        }

        guard let oldIdx = model.captions.firstIndex(where: { $0.languageCode == old }) else {
            return
        }

        model.captions[oldIdx].languageCode = new
    }

    private func publishChangesAndDismiss() {
        guard let model else { return }
        editingManager.publishChanges(of: model)
        dismiss()
    }
}


#Preview {
    FileEditView(mediaFileInfo: .makeRandomUploaded(id: "12", .squareImage), resolvedTags: [.init(.earth)])
}
