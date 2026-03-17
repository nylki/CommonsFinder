//
//  MultiDraftView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.03.26.
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

struct MultiDraftView: View {
    @Bindable var model: MultiDraftModel

    @Environment(UploadManager.self) private var uploadManager
    @Environment(AccountModel.self) private var account
    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.locale) private var locale
    @Environment(FileAnalysis.self) private var fileAnalysis
    @FocusState private var focus: FocusElement?

    @State private var filenameSelection: TextSelection?
    @State private var isLicensePickerShowing = false
    @State private var isTimezonePickerShowing = false
    @State private var locationLabel: String?
    @State private var isZoomableImageViewerPresented = false
    @State private var isFilenameErrorSheetPresented = false
    @State private var isShowingDeleteDialog = false
    @State private var isShowingUploadDialog = false
    @State private var isShowingCloseConfirmationDialog = false
    @State private var isShowingUploadDisabledAlert = false
    @State private var isShowingTagsPicker = false
    @State private var isShowingCategoryPicker = false

    private var draftExistsInDB: Bool {
        model.info.multiDraft.id != nil
    }

    private enum FocusElement: Hashable {
        case caption
        case description
        case tags
        case license
        case filename
    }

    var body: some View {
        Form {
            imageCarouselView
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
        .navigationTitle("Draft (\(model.info.drafts.count) files)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .scrollDismissesKeyboard(.interactively)
        .interactiveDismissDisabled(!draftExistsInDB)
        // NOTE: Not using a regular sheet here: .sheet + ScrollView + ForEach Buttons causes accidental button taps when scrolling (SwiftUI bug?)
        // so for now until this behaviour is fixed by Apple
        // this is a fullScreenCover (but TODO: consider using a push navigation here)
        .fullScreenCover(isPresented: $isShowingTagsPicker) {
            TagPicker(
                initialTags: model.info.multiDraft.tags,
                onEditedTags: {
                    model.info.multiDraft.tags = $0
                }
            )
        }
//        .sheet(isPresented: $isTimezonePickerShowing) {
//            TimezonePicker(selectedTimezone: $model.multiDraft.timezone)
//                .presentationDetents([.medium, .large])
//        }

        .onAppear {
            if model.info.multiDraft.captionWithDesc.isEmpty {
                focus = .caption
            }
        }
        .onChange(of: model.info) {
            if focus != .filename {
                generateFilename()
            }
            
            model.info.multiDraft.uploadPossibleStatus = DraftValidation.canUploadDraft(
                model.info.multiDraft,
                nameValidationResult: model.nameValidationResult.values.first
            )
        }
        .onChange(of: model.info.multiDraft.selectedFilenameType) { oldValue, newValue in
            filenameSelection = .none
            if newValue != .custom {
                generateFilename()
            }
        }
//        .onDisappear {
//            if draftExistsInDB, model.multiDraft.publishingState == nil {
//                saveChanges()
//            }
//        }
//        .task(id: model.multiDraft.name) {
//            do {
//                try await model.validateFilenameImpl()
//            } catch {
//                logger.error("Failed to validate name \(error)")
//            }
//        }
//        .task(id: model.multiDraft.id) {
//            fileAnalysis.startAnalyzingIfNeeded(model.multiDraft)
//        }
//        .task(id: model.choosenCoordinate) {
//            locationLabel = nil
//            guard let coordinate = model.choosenCoordinate else { return }
//            do {
//                locationLabel = try await coordinate.generateHumanReadableString()
//            } catch {
//                logger.error("failed generateHumanReadableString \(error)")
//            }
//        }
    }


    private func generateFilename() {
        // TODO: move to model
        Task<Void, Never> {
            let generatedFilename =
                await model.info.multiDraft.selectedFilenameType.generateFilename(
                    // FIXME: coordinate?
                    coordinate: nil,
                    date: model.info.drafts.first?.inceptionDate,
                    desc: model.info.multiDraft.captionWithDesc,
                    locale: locale,
                    tags: model.info.multiDraft.tags
                ) ?? model.info.multiDraft.name

            model.info.multiDraft.name = generatedFilename
        }
    }

    private func saveChanges() {
        do {
            try appDatabase.upsert(model.info)
        } catch {
            logger.error("Failed to save all drafts \(error)")
        }
    }

    private func saveChangesAndDismiss() {
        saveChanges()
        dismiss()
    }

    private func deleteDraftAndDismiss() {
        do {
            try appDatabase.delete(model.info)
            dismiss()
        } catch {
            logger.error("Failed to delete drafts \(error)")
        }
    }
    @ViewBuilder
    private var captionAndDescriptionSection: some View {
        Section("Description") {
            let enumeratedDescs = Array(model.info.multiDraft.captionWithDesc.enumerated())
            let disabledLanguages = model.info.multiDraft.captionWithDesc.map(\.languageCode)

            List {
                ForEach(enumeratedDescs, id: \.element.languageCode) { (idx, desc) in
                    let languageCode = desc.languageCode

                    VStack(alignment: .leading) {
                        Menu(WikimediaLanguage(code: languageCode).localizedDescription) {
                            Text("Select Language")
                            Divider()
                            LanguageButtons(disabledLanguages: disabledLanguages) { selectedLanguage in
                                changeLanguageForCaptionAndDesc(old: languageCode, new: selectedLanguage.code)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                model.info.multiDraft.captionWithDesc.remove(at: idx)
                            }

                        }

                        TextField(
                            "caption",
                            text: $model.info.multiDraft.captionWithDesc[languageCode, .caption],
                            axis: .vertical
                        )
                        .bold()
                        .focused($focus, equals: .caption)
                        .submitLabel(.next)
                        .onChange(of: model.info.multiDraft.captionWithDesc[languageCode, .caption]) { oldValue, newValue in
                            if newValue.count > 250 {
                                model.info.multiDraft.captionWithDesc[languageCode, .caption] = String(model.info.multiDraft.captionWithDesc[languageCode, .caption].prefix(250))
                            }
                        }
                        .safeAreaInset(edge: .bottom) {
                            let captionLength = model.info.multiDraft.captionWithDesc[languageCode, .caption].count
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
                            text: $model.info.multiDraft.captionWithDesc[languageCode, .description],
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
                    model.info.multiDraft.captionWithDesc.remove(atOffsets: set)
                }

                Menu("Add", systemImage: "plus") {
                    Text("Choose language")
                    LanguageButtons(disabledLanguages: disabledLanguages, onSelect: { addLanguage(code: $0.code) })
                }
            }


        }
    }

    private func addLanguage(code: LanguageCode) {
        guard !model.info.multiDraft.captionWithDesc.contains(where: { $0.languageCode == code }) else {
            assertionFailure("We expect the language code to not exist yet")
            return
        }

        withAnimation {
            model.info.multiDraft.captionWithDesc.append(.init(languageCode: code))
        }
    }

    private func changeLanguageForCaptionAndDesc(old: LanguageCode, new: LanguageCode) {
        // dont change language if same, or if the new language already exists
        // this is an assertion failure, as these actions should be disabled in the UI above.
        guard old != new,
            model.info.multiDraft.captionWithDesc.first(where: { $0.languageCode == new }) == nil
        else {
            assertionFailure()
            return
        }

        guard let idx = model.info.multiDraft.captionWithDesc.firstIndex(where: { $0.languageCode == old }) else {
            assertionFailure("We expect the given old language code to both have an existing caption and desc in the draft")
            return
        }

        model.info.multiDraft.captionWithDesc[idx].languageCode = new
    }


    private var filenameSection: some View {
        // FIXME: only check first and last filename, dynamically
        // check all filenames when uploading?
        Section {
            HStack {
                TextField("Filename", text: $model.info.multiDraft.name, selection: $filenameSelection, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .focused($focus, equals: .filename)
                    .tint(.primary)
                    .padding(.trailing)
                Spacer(minLength: 0)
                
//                if model.nameValidationResult == nil {
//                    ProgressView()
//                } else {
//                    Button {
//                        switch model.nameValidationResult {
//                        case .success(_), .none:
//                            // do nothing, alternatively, tell user, the full filename including name ending and
//                            // that it was checked with the backend?
//                            break
//                        case .failure(_):
//                            isFilenameErrorSheetPresented = true
//                        }
//
//                    } label: {
//                        switch model.nameValidationResult {
//                        case .failure(_), .none:
//                            Image(systemName: "exclamationmark.circle")
//                                .foregroundStyle(.red)
//                        case .success(_):
//                            Image(systemName: "checkmark.circle")
//                                .foregroundStyle(.green)
//                        }
//                    }
//                    .alert(
//                        model.nameValidationResult?.alertTitle ?? "", isPresented: $isFilenameErrorSheetPresented, presenting: model.nameValidationResult?.error,
//                        actions: { error in
//                            if case .invalid(let localInvalidationError) = error,
//                                localInvalidationError?.canBeAutoFixed == true,
//                                model.multiDraft.selectedFilenameType == .custom
//                            {
//                                Button("sanitize") {
//                                    filenameSelection = .none
//                                    model.multiDraft.name = LocalFileNameValidation.sanitizeFileName(model.multiDraft.name)
//                                }
//                            }
//                            Button("Ok") {
//                                let endIdx = model.multiDraft.name.endIndex
//                                focus = .filename
//                                filenameSelection = .init(range: endIdx..<endIdx)
//                            }
//                        },
//                        message: { error in
//                            let failureReason = model.nameValidationResult?.error?.failureReason
//                            let recoverySuggestion = model.nameValidationResult?.error?.recoverySuggestion
//
//                            let isFailureReasonIdenticalToTitle = failureReason == model.nameValidationResult?.alertTitle
//                            if let failureReason, let recoverySuggestion, !isFailureReasonIdenticalToTitle {
//                                Text(failureReason + "\n\n\(recoverySuggestion)")
//                            } else if let recoverySuggestion {
//                                Text(recoverySuggestion)
//                            }
//
//                        }
//                    )
//
//                    .imageScale(.large)
//                    .frame(width: 10)
//                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)

        } header: {
            Text("file name")
        } footer: {
            Menu {
                ForEach(model.suggestedFilenames, id: \.type) { suggested in
                    Button {
                        model.info.multiDraft.selectedFilenameType = suggested.type
                        model.info.multiDraft.name = suggested.name
                    } label: {
                        Text(suggested.name)
                        Text(suggested.type.description)
                    }

                }
            } label: {
                Label(
                    model.info.multiDraft.selectedFilenameType.description,
                    systemImage: model.info.multiDraft.selectedFilenameType.systemIconName
                )
            }
        }
        .task(id: model.info.multiDraft.name) {
            // TODO: generate in model of name change
            var generatedSuggestions: [FileNameTypeTuple] = []
            for type in FileNameType.automaticTypes {
                let generatedFilename =
                    await type.generateFilename(
                        coordinate: nil,
                        // FIXME: check if date is identical everywhere, find other solution (eg. <date> token placeholder)
                        // for UI
                        // so the date is filled automatically?
                        date: model.info.drafts.first?.inceptionDate,
                        desc: model.info.multiDraft.captionWithDesc,
                        locale: Locale.current,
                        tags: model.info.multiDraft.tags
                    )

                if let generatedFilename {
                    generatedSuggestions.append(.init(name: generatedFilename, type: type))
                }

            }

            model.suggestedFilenames = generatedSuggestions

            guard !model.info.multiDraft.name.isEmpty else { return }

            let matchingAutomatic = generatedSuggestions.first(where: { suggestion in
                model.info.multiDraft.name == suggestion.name
            })

            if let matchingAutomatic {
                model.info.multiDraft.selectedFilenameType = matchingAutomatic.type
            } else {
                model.info.multiDraft.selectedFilenameType = .custom
            }
        }

    }


    private var tagsSection: some View {
        Section {
            let tags: [TagItem] = model.info.multiDraft.tags

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
                .animation(.default, value: model.info.multiDraft.tags)


            }

            Button(
                model.info.multiDraft.tags.isEmpty ? "Add" : "Edit",
                systemImage: model.info.multiDraft.tags.isEmpty ? "plus" : "pencil"
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
                Toggle("Locations", systemImage: model.info.multiDraft.locationEnabled ? "location" : "location.slash", isOn: $model.info.multiDraft.locationEnabled)
                    .animation(.default) {
                        $0.contentTransition(.symbolEffect)
                    }
                if model.info.multiDraft.locationEnabled == false {
                    Text("Location metadata will be erased from all \(model.info.drafts.count) files before uploading.")
                        .font(.caption)
                } else if !model.choosenCoordinates.isEmpty {
                    FileLocationMapView(coordinates: model.choosenCoordinates, label: locationLabel)
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
                    if let license = model.info.multiDraft.license {
                        Text(license.abbreviation)
                    } else {
                        Text("choose")
                    }
                }
                .focused($focus, equals: .license)

            }
            .sheet(isPresented: $isLicensePickerShowing) {
                LicensePicker(selectedLicense: $model.info.multiDraft.license, allowsEmptySelection: false)
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
    var imageCarouselView: some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: [.init(), .init(), .init()]) {
                ForEach(model.info.drafts) { draft in
                            Button {
                                isZoomableImageViewerPresented = true
                            } label: {
                                LazyImage(request: draft.localFileRequestResized) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .transition(.blurReplace)
                                            .clipShape(.containerRelative)
                                    } else {
                                        Color.clear.background(.regularMaterial)
                                    }
                                }
                            }
                            .buttonStyle(ImageButtonStyle())
                    
                    

                }
            }
            .containerShape(ViewConstants.draftImageCarouselContainerShape)
        }
        .frame(maxHeight: 300)
        .listRowInsets(.init())
        .listRowBackground(Color.clear)

        
//        // we only expect the model.fileItem?.fileURL, but thumburl is useful for previews
//        Button {
//            isZoomableImageViewerPresented = true
//        } label: {
//            LazyImage(request: model.imageRequest) { phase in
//                if let image = phase.image {
//                    image
//                        .resizable()
//                        .aspectRatio(contentMode: .fill)
//                        .transition(.blurReplace)
//                        .clipShape(.containerRelative)
//                } else {
//                    Color.clear.background(.regularMaterial)
//                }
//            }
//        }
        .buttonStyle(ImageButtonStyle())
//        .containerRelativeFrame(.horizontal)
//        .listRowInsets(.init())
//        .listRowBackground(Color.clear)
//        .zoomableImageFullscreenCover(
//            imageReference: model.zoomableImageReference,
//            isPresented: $isZoomableImageViewerPresented
//        )
    }


    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button("Close", systemImage: "xmark", role: .fallbackClose) {
                if draftExistsInDB {
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

        if draftExistsInDB {
            ToolbarItem(placement: .destructiveAction) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    isShowingDeleteDialog = true
                }
                .confirmationDialog(
                    "Are you sure you want to delete the Draft?",
                    isPresented: $isShowingDeleteDialog,
                    titleVisibility: .visible
                ) {
                    Button("Delete", systemImage: "trash", role: .destructive, action: deleteDraftAndDismiss)

                    Button("Cancel", role: .cancel) { isShowingDeleteDialog = false }
                }
            }
        }


        ToolbarItem(placement: .confirmationAction) {
            if model.info.multiDraft.uploadPossibleStatus == .uploadPossible {
                Button {
                    isShowingUploadDialog = true
                } label: {
                    Label("Upload", systemImage: "arrow.up")
                }
                .confirmationDialog("Start upload to Wikimedia Commons now?", isPresented: $isShowingUploadDialog, titleVisibility: .visible) {
                    Button("Upload", systemImage: "square.and.arrow.up", role: .fallbackConfirm) {
                        guard let username = account.activeUser?.username else {
                            assertionFailure()
                            return
                        }
                        saveChanges()
                        // FIXME: actual upload
//                        uploadManager.upload(model.info.multiDraft, username: username)
                        dismiss()
                    }

                    Button("Cancel", role: .cancel) {
                        isShowingDeleteDialog = false
                    }
                }
            } else {
                Button {
                    isShowingUploadDisabledAlert = true
                } label: {
                    Label("Info", systemImage: "arrow.up")
                }
                .tint(Color.gray.opacity(0.5))
                .alert(
                    "Upload not possible", isPresented: $isShowingUploadDisabledAlert,
                    actions: {
                        Button("Ok") {
                            switch model.info.multiDraft.uploadPossibleStatus {
                            case .uploadPossible: break
                            case .notLoggedIn: break
                            case .missingCaptionOrDescription:
                                focus = .caption
                            case .missingLicense:
                                focus = .license
                            case .missingTags:
                                focus = .tags
                            case .validationError(let nameValidationError):
                                focus = .filename
                            case .failedToValidate: break
                            case .none: break
                            }
                        }
                    },
                    message: {
                        switch model.info.multiDraft.uploadPossibleStatus {
                        case .uploadPossible:
                            Text("Unknown error, please make a screenshot and report this issue if you see this.")
                        case .notLoggedIn:
                            Text("You must be logged in to a Wikimedia account to upload files.")
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
        }


    }
}


#Preview("New Draft", traits: .previewEnvironment) {
    @Previewable @State var draft = MultiDraftModel(.makeRandom(id: 1))

    MultiDraftView(model: draft)
}

#Preview("With Metadata", traits: .previewEnvironment) {
    @Previewable @State var draft = MultiDraftModel(.makeRandom(id: 1))

    MultiDraftView(model: draft)
}
