//
//  MultiDraftCombinedView.swift
//  CommonsFinder
//
//  Created by Tom on 22.07.26.
//

import CommonsAPI
import FrameUp
@preconcurrency import MapKit
import NukeUI
import OrderedCollections
import SwiftUI
import TipKit
import UniformTypeIdentifiers
import os.log

struct MultiDraftCombinedView: View {
    @Bindable var model: MultiDraftModel


    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @Environment(\.appDatabase) private var appDatabase
    @Environment(AccountModel.self) private var account
    @Environment(FileAnalysis.self) private var fileAnalysis
    @FocusState private var focus: FocusElement?

    @State private var filenameSelection: TextSelection?
    @State private var isLicensePickerShowing = false
    @State private var isTimezonePickerShowing = false

    @State private var isZoomableImageViewerPresented = false
    @State private var zoomableImageReference: ZoomableImageReference?

    @State private var isShowingDeleteDialog = false
    @State private var isShowingCloseConfirmationDialog = false
    @State private var isShowingContinueDisabledAlert = false

    @State private var isShowingTagsPicker = false
    @State private var isShowingCategoryPicker = false

    @State private var warningTips: TipGroup?

    private enum FocusElement: Hashable {
        case caption
        case description
        case tags
        case license
        case filename
    }

    private var imageGridRows: [GridItem] {
        let draftCount = model.subDraftModels.count
        return if draftCount <= 3 {
            [.init()]
        } else if draftCount <= 6 {
            [.init(), .init()]
        } else {
            [.init(), .init(), .init()]
        }
    }

    private var analysisInput: FileAnalysis.Input? {
        return if let centroidCoordinate = model.centroidCoordinate {
            .fileLocation(centroidCoordinate, horizontalError: model.minimumBoundingCircleRadiusOfCoordinates, bearing: nil)
        } else {
            nil
        }
    }

    var body: some View {
        Form {
            imageGrid

            captionAndDescriptionSection
            tagsSection
            locationSection
            attributionSection
            //            dateTimeSection
            filenameSection

            Color.clear
                .frame(height: 50)
                .listRowBackground(Color.clear)
        }
        .fallbackSafeAreaBar(edge: .top) {
            if let currentWarningTip = warningTips?.currentTip {
                TipView(currentWarningTip)
                    .padding()
            }
        }
        .navigationTitle("Draft")
        .navigationSubtitleFallback(subtitle: Text("\(model.subDraftModels.count) files"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .scrollDismissesKeyboard(.interactively)
        .interactiveDismissDisabled(!model.draftExistsInDB)
        // NOTE: Not using a regular sheet here: .sheet + ScrollView + ForEach Buttons causes accidental button taps when scrolling (SwiftUI bug?)
        // so for now until this behaviour is fixed by Apple
        // this is a fullScreenCover (but TODO: consider using a push navigation here)
        .fullScreenCover(isPresented: $isShowingTagsPicker) {
            TagPicker(
                initialTags: model.multiDraft.tags,
                analysisInput: analysisInput,
                onEditedTags: { model.multiDraft.tags = $0 },
            )
        }
        .onAppear {
            if model.multiDraft.captionWithDesc.isEmpty {
                focus = .caption
            }
            warningTips = TipGroup {
                if model.filesCreatedOnDifferentDays {
                    MultiDraftDateSpreadTip(multiDraftID: model.multiDraft.id)
                }
                if model.filesCreatedInSpreadOutLocations {
                    MultiDraftLocationSpreadTip(multiDraftID: model.multiDraft.id)
                }
            }
        }
        .onChange(of: model.multiDraft) {
            if focus != .filename {
                model.generateFilename()
            }

            model.multiDraft.uploadPossibleStatus = DraftValidation.canUploadDraft(
                model.multiDraft,
                nameValidationResult: model.nameValidationResult
            )
        }
        .onChange(of: model.multiDraft.selectedFilenameType) { oldValue, newValue in
            filenameSelection = .none
            if newValue != .custom {
                model.generateFilename()
            }
        }
        .onDisappear {
            if model.draftExistsInDB, model.multiDraft.publishingState == nil {
                do {
                    try model.saveEditingChanges(appDatabase: appDatabase)
                } catch {
                    logger.error("Failed to save editing changes")
                }
            }
        }
        .task(id: model.multiDraft.name) {
            do {
                try await model.validateFilenameImpl()
            } catch {
                logger.error("Failed to validate combined file name \(error)")
            }
        }
        .task(id: analysisInput) {
            if let analysisInput {
                fileAnalysis.startAnalyzingIfNeeded(analysisInput)
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

    @ViewBuilder
    private var captionAndDescriptionSection: some View {
        Section("Description") {
            let enumeratedDescs = Array(model.multiDraft.captionWithDesc.enumerated())
            let disabledLanguages = model.multiDraft.captionWithDesc.map(\.languageCode)

            List {
                ForEach(enumeratedDescs, id: \.element.languageCode) { (idx, desc) in
                    let languageCode = desc.languageCode
                    let languageName = Locale.LanguageCode(languageCode).localizedLanguageName
                    VStack(alignment: .leading) {
                        Menu(languageName) {
                            Text("Select Language")
                            Divider()
                            InputLanguageButtons(disabledLanguages: disabledLanguages) { selectedLanguage in
                                changeLanguageForCaptionAndDesc(old: languageCode, new: selectedLanguage.code)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                model.multiDraft.captionWithDesc.remove(at: idx)
                            }

                        }

                        TextField(
                            "caption",
                            text: $model.multiDraft.captionWithDesc[languageCode, .caption],
                            axis: .vertical
                        )
                        .bold()
                        .focused($focus, equals: .caption)
                        .submitLabel(.next)
                        .onChange(of: model.multiDraft.captionWithDesc[languageCode, .caption]) { oldValue, newValue in
                            if newValue.count > 250 {
                                model.multiDraft.captionWithDesc[languageCode, .caption] = String(model.multiDraft.captionWithDesc[languageCode, .caption].prefix(250))
                            }
                        }
                        .safeAreaInset(edge: .bottom) {
                            let captionLength = model.multiDraft.captionWithDesc[languageCode, .caption].count
                            if captionLength > 225 {
                                HStack {
                                    Text("\(captionLength)/250 characters")
                                        .font(.caption)
                                        .foregroundStyle(captionLength == 250 ? Color.red : .secondary)
                                    Spacer(minLength: 0)
                                }
                            }
                        }

                        .onSubmit {
                            focus = .description
                        }

                        TextField(
                            "detailed description (optional)",
                            text: $model.multiDraft.captionWithDesc[languageCode, .description],
                            axis: .vertical
                        )
                        .focused($focus, equals: .description)
                        .submitLabel(.next)
                        .onSubmit {
                            focus = .tags
                        }
                    }

                }
                .onDelete { set in
                    model.multiDraft.captionWithDesc.remove(atOffsets: set)
                }

                Menu(enumeratedDescs.count == 0 ? "Add" : "Add Language", systemImage: "plus") {
                    Text("Choose language")
                    InputLanguageButtons(disabledLanguages: disabledLanguages, onSelect: { addLanguage(code: $0.code) })
                }
            }


        }
    }

    private func addLanguage(code: LanguageCode) {
        guard !model.multiDraft.captionWithDesc.contains(where: { $0.languageCode == code }) else {
            assertionFailure("We expect the language code to not exist yet")
            return
        }

        withAnimation {
            model.multiDraft.captionWithDesc.append(.init(languageCode: code))
        }
    }

    private func changeLanguageForCaptionAndDesc(old: LanguageCode, new: LanguageCode) {
        // dont change language if same, or if the new language already exists
        // this is an assertion failure, as these actions should be disabled in the UI above.
        guard old != new,
            model.multiDraft.captionWithDesc.first(where: { $0.languageCode == new }) == nil
        else {
            assertionFailure()
            return
        }

        guard let idx = model.multiDraft.captionWithDesc.firstIndex(where: { $0.languageCode == old }) else {
            assertionFailure("We expect the given old language code to both have an existing caption and desc in the draft")
            return
        }

        model.multiDraft.captionWithDesc[idx].languageCode = new
    }


    private var filenameSection: some View {
        Section {
            HStack {
                TextField("Filename", text: $model.multiDraft.name, selection: $filenameSelection, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .focused($focus, equals: .filename)
                    .tint(.primary)
                    .padding(.trailing)
                Spacer(minLength: 0)

                if let nameValidationResult = model.nameValidationResult {
                    FilenameErrorButton(
                        nameValidationResult: nameValidationResult,
                        fileNameType: model.multiDraft.selectedFilenameType,
                        onDismiss: {
                            let endIdx = model.multiDraft.name.endIndex
                            focus = .filename
                            filenameSelection = .init(range: endIdx..<endIdx)
                        },
                        onSanitize: {
                            filenameSelection = .none
                            model.multiDraft.name = LocalFileNameValidation.sanitizeFileName(model.multiDraft.name)
                        }
                    )
                } else {
                    ProgressView()
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)

            let filenamePreviewWithRange = try? FilenameUtils.finalFilenamePreviewWithRange(
                multiDraft: model.multiDraft,
                totalFilesCount: model.subDraftModels.count,
                mimeTypes: model.subDraftModels.values.map(\.draft.mimeType)
            )

            switch filenamePreviewWithRange {
            case .identicalMimetypes(let previewString):
                Text(previewString)
                    .foregroundStyle(.secondary)
            case .differingMimetypes, .none:
                Text("Show file list with filenames")
            }

        } header: {
            Text("file name")
        } footer: {
            Menu {
                ForEach(model.suggestedFilenames, id: \.type) { suggested in
                    Button {
                        model.multiDraft.selectedFilenameType = suggested.type
                        model.multiDraft.name = suggested.name
                    } label: {
                        Text(suggested.name)
                        Text(suggested.type.description)
                    }

                }
            } label: {
                if let selectedFilenameType = model.multiDraft.selectedFilenameType {
                    Label(
                        selectedFilenameType.description,
                        systemImage: selectedFilenameType.systemIconName
                    )
                } else {
                    EmptyView()
                }

            }
        }
        .task(id: model.multiDraft.name) {
            // TODO: generate in model of name change

            let firstFileDate = model.exifData.first?.value.dateOriginal

            let allFilesCreatedOnSameDay = model.subDraftModels.values.map(\.draft)
                .allSatisfy({ draft in
                    if let firstFileDate, let date = model.exifData[draft.id]?.dateOriginal {
                        Calendar.current.isDate(date, inSameDayAs: firstFileDate)
                    } else {
                        false
                    }
                })

            let possibleTypes: [FileNameType] =
                if allFilesCreatedOnSameDay {
                    [.captionAndDate, .captionOnly]
                } else {
                    [.captionOnly]
                }

            if model.multiDraft.selectedFilenameType == nil {
                model.multiDraft.selectedFilenameType = possibleTypes.first
            }

            var generatedSuggestions: [FileNameTypeTuple] = []

            for type in possibleTypes {
                let generatedFilename =
                    await type.generateFilename(
                        coordinate: model.centroidCoordinate,
                        date: model.subDraftModels.values.first?.draft.inceptionDate,
                        desc: model.multiDraft.captionWithDesc,
                        locale: Locale.current,
                        tags: model.multiDraft.tags
                    )

                if let generatedFilename {
                    generatedSuggestions.append(.init(name: generatedFilename, type: type))
                }

            }

            model.suggestedFilenames = generatedSuggestions

            guard !model.multiDraft.name.isEmpty else { return }


            if model.multiDraft.selectedFilenameType == nil {
                model.multiDraft.selectedFilenameType = generatedSuggestions.first?.type
            } else {
                let matchingAutomatic = generatedSuggestions.first(where: { suggestion in
                    model.multiDraft.name == suggestion.name
                })
                if let matchingAutomatic {
                    model.multiDraft.selectedFilenameType = matchingAutomatic.type
                } else {
                    model.multiDraft.selectedFilenameType = .custom
                }
            }
        }

    }


    private var tagsSection: some View {
        Section {
            let tags: [TagItem] = model.multiDraft.tags

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
                .animation(.default, value: model.multiDraft.tags)


            }

            Button(
                model.multiDraft.tags.isEmpty ? "Add" : "Edit",
                systemImage: model.multiDraft.tags.isEmpty ? "plus" : "pencil"
            ) {
                isShowingTagsPicker = true
            }
            .focused($focus, equals: .tags)
        } header: {
            Label("Tags", systemImage: "tag")
        } footer: {
            Text("Add **categories** and define what the image **depicts**. This makes your image discoverable and useful.")
        }
    }

    @ViewBuilder
    private var locationSection: some View {
        Section {
            VStack(alignment: .leading) {
                Toggle("Locations", systemImage: model.multiDraft.locationEnabled ? "location" : "location.slash", isOn: $model.multiDraft.locationEnabled)
                    .animation(.default) {
                        $0.contentTransition(.symbolEffect)
                    }
                if model.multiDraft.locationEnabled == false {
                    Text("Location metadata will be erased from all \(model.subDraftModels.count) files before uploading.")
                        .font(.caption)
                } else if !model.choosenMapItems.isEmpty {
                    DraftInlineMapView(items: model.choosenMapItems)
                }
            }
        }

    }


    @ViewBuilder
    private var attributionSection: some View {
        Section("License and Attribution") {
            HStack {
                Text("License")
                Spacer()
                Button {
                    isLicensePickerShowing = true
                } label: {
                    if let license = model.multiDraft.license {
                        Text(license.abbreviation)
                    } else {
                        Text("choose")
                    }
                }
                .focused($focus, equals: .license)

            }
            .sheet(isPresented: $isLicensePickerShowing) {
                LicensePicker(selectedLicense: $model.multiDraft.license, allowsEmptySelection: false)
            }


            HStack {
                // TODO: extend this, atleast with a helper text
                // about what is ok to upload and what not.

                Text("Source")
                Spacer()
                Text("Own Work")
            }
        }
    }

    @ViewBuilder
    var imageGrid: some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: imageGridRows) {
                ForEach(model.subDraftModels.values.map(\.draft), id: \.id) { draft in
                    Button {
                        if let localFileRequestResized = draft.localFileRequestFull {
                            zoomableImageReference = .localImage(.init(image: localFileRequestResized, fullWidth: draft.width, fullHeight: draft.height, fullByte: nil))
                            isZoomableImageViewerPresented = true
                        } else {
                            assertionFailure()
                        }
                    } label: {
                        BaseDraftImageView(draft: draft, size: .thumb)
                            .clipShape(ViewConstants.draftImageCarouselContainerShape)
                    }
                    .frame(maxWidth: 180, maxHeight: 180)
                    .buttonStyle(ImageButtonStyle())
                }
            }

        }
        .frame(maxHeight: 300)
        .listRowInsets(.init())
        .listRowBackground(Color.clear)
        .padding(.horizontal)
        .zoomableImageFullscreenCover(
            imageReference: zoomableImageReference,
            isPresented: $isZoomableImageViewerPresented
        )
    }

    private var continueDisabledButton: some View {
        Button {
            isShowingContinueDisabledAlert = true
        } label: {
            Label("Continue", systemImage: "arrow.right")
        }
        .tint(Color.gray.opacity(0.5))
        .alert(
            "More input required", isPresented: $isShowingContinueDisabledAlert,
            actions: {
                Button("Ok") {}
            },
            message: {
                switch model.multiDraft.uploadPossibleStatus {
                case .uploadPossible:
                    Text("Unknown error, please make a screenshot and report this issue if you see this.")
                case .missingCaptionOrDescription:
                    Text("Please provide a caption or description for your files. Individual captions can be adjusted in the next step.")
                case .missingLicense:
                    Text("You must choose the license under which you want to publish the files. Individual file licenses can be adjusted in the next step.")
                case .missingTags:
                    Text("You should add atleast one category or depicted item in the Tags-section. Individual categories can be adjusted in the next step.")
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


    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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
            if model.multiDraft.uploadPossibleStatus == .uploadPossible {
                Button("Continue", systemImage: "arrow.forward") {
                    do {
                        try model.copyFieldsIntoSubDrafts(appDatabase: appDatabase)
                    } catch {
                        logger.error("Error copying multidraft fields into individual sub drafts")
                    }
                }
            } else {
                continueDisabledButton
            }
        }

    }
}

#Preview("New Draft", traits: .previewEnvironment) {
    @Previewable @State var draft = MultiDraftModel(.makeRandom(id: 1, imageCount: 5))

    MultiDraftCombinedView(model: draft)
}

#Preview("With Metadata", traits: .previewEnvironment) {
    @Previewable @State var draft = MultiDraftModel(.makeRandom(id: 1, imageCount: 5))

    MultiDraftCombinedView(model: draft)
}
