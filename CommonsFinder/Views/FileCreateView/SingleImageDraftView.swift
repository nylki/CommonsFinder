//
//  MetadataEditForm.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 13.10.24.
//

import CommonsAPI
import FrameUp
@preconcurrency import MapKit
import NukeUI
import SwiftUI
import TipKit
import UniformTypeIdentifiers
import os.log

struct SingleImageDraftView: View {
    @Bindable var model: MediaFileDraftModel

    @Environment(UploadManager.self) private var uploadManager
    @Environment(AccountModel.self) private var account
    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.locale) private var locale
    @FocusState private var focus: FocusElement?

    @State private var filenameSelection: TextSelection?
    @State private var isLicensePickerShowing = false
    @State private var isTimezonePickerShowing = false
    @State private var locationLabel: String?
    @State private var isZoomableImageViewerPresented = false

    @State private var isFilenameErrorSheetPresented = false


    // TODO: check if any states are superfluous now
    @State private var isShowingDeleteDialog = false
    @State private var isShowingUploadDialog = false
    @State private var isShowingCloseConfirmationDialog = false
    @State private var isShowingUploadDisabledAlert = false

    private var draftExistsInDB: Bool {
        do {
            return try appDatabase.draftExists(id: model.draft.id)
        } catch {
            return false
        }
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
            imageView
            captionAndDescriptionSection
            tagsSection
            locationSection
            attributionSection
            dateTimeSection
            filenameSection

            Color.clear
                .frame(height: 50)
                .listRowBackground(Color.clear)
        }
        .toolbar { toolbarContent }
        .scrollDismissesKeyboard(.interactively)
        // NOTE: Not using a regular sheet here: .sheet + ScrollView + ForEach Buttons causes accidental button taps when scrolling (SwiftUI bug?)
        // so for now until this behaviour is fixed by Apple
        // this is a fullScreenCover (but TODO: consider using a push navigation here)
        .fullScreenCover(isPresented: $model.isShowingStatementPicker) {
            let suggestedNearbyTags = model.analysisResult?.nearbyCategories.map { TagItem($0) } ?? []

            TagPicker(
                initialTags: model.draft.tags,
                suggestedNearbyTags: suggestedNearbyTags,
                onEditedTags: {
                    model.draft.tags = $0
                }
            )
        }
        .sheet(isPresented: $isTimezonePickerShowing) {
            TimezonePicker(selectedTimezone: $model.draft.timezone)
                .presentationDetents([.medium, .large])
        }

        .onAppear {
            if model.draft.captionWithDesc.isEmpty {
                focus = .caption
            }
        }
        .onChange(of: model.draft) {
            if focus != .filename {
                generateFilename()
            }
            model.draft.uploadPossibleStatus = model.canUploadDraft()
        }
        .onChange(of: model.draft.selectedFilenameType) { oldValue, newValue in
            filenameSelection = .none
            if newValue != .custom {
                generateFilename()
            }
        }
        .task(id: model.draft.name) {
            do {
                try await model.validateFilenameImpl()
            } catch {
                logger.error("Failed to validate name \(error)")
            }
        }
        .task {
            await model.analyzeImage()
        }
        .task(id: model.choosenCoordinate) {
            locationLabel = nil
            guard let coordinate = model.choosenCoordinate else { return }
            do {
                locationLabel = try await coordinate.generateHumanReadableString()
            } catch {
                logger.error("failed generateHumanReadableString \(error)")
            }
        }
    }


    private func generateFilename() {
        // TODO: move to model
        Task<Void, Never> {
            let generatedFilename =
                await model.draft.selectedFilenameType.generateFilename(
                    coordinate: model.exifData?.coordinate,
                    date: model.draft.inceptionDate,
                    desc: model.draft.captionWithDesc,
                    locale: locale,
                    tags: model.draft.tags
                ) ?? model.draft.name

            model.draft.name = generatedFilename
        }
    }

    private func saveChanges() {
        do {
            if let fileItem = model.fileItem {
                model.draft.localFileName = fileItem.localFileName
            }
            try appDatabase.upsert(model.draft)
            dismiss()
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
            try appDatabase.delete(model.draft)
            dismiss()
        } catch {
            logger.error("Failed to delete drafts \(error)")
        }
    }
    @ViewBuilder
    private var captionAndDescriptionSection: some View {
        Section("Caption and Description") {
            let enumeratedDescs = Array(model.draft.captionWithDesc.enumerated())
            let disabledLanguages = model.draft.captionWithDesc.map(\.languageCode)

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
                                model.draft.captionWithDesc.remove(at: idx)
                            }

                        }

                        TextField(
                            "caption",
                            text: $model.draft.captionWithDesc[languageCode, .caption],
                            axis: .vertical
                        )
                        .bold()
                        .focused($focus, equals: .caption)
                        .submitLabel(.next)
                        .onSubmit {
                            focus = .description
                        }

                        TextField(
                            "detailed description (optional)",
                            text: $model.draft.captionWithDesc[languageCode, .description],
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
                    model.draft.captionWithDesc.remove(atOffsets: set)
                }

                Menu("Add", systemImage: "plus") {
                    Text("Choose language")
                    LanguageButtons(disabledLanguages: disabledLanguages, onSelect: { addLanguage(code: $0.code) })
                }
            }


        }
    }

    private func addLanguage(code: LanguageCode) {
        guard !model.draft.captionWithDesc.contains(where: { $0.languageCode == code }) else {
            assertionFailure("We expect the language code to not exist yet")
            return
        }

        withAnimation {
            model.draft.captionWithDesc.append(.init(languageCode: code))
        }
    }

    private func changeLanguageForCaptionAndDesc(old: LanguageCode, new: LanguageCode) {
        // dont change language if same, or if the new language already exists
        // this is an assertion failure, as these actions should be disabled in the UI above.
        guard old != new,
            model.draft.captionWithDesc.first(where: { $0.languageCode == new }) == nil
        else {
            assertionFailure()
            return
        }

        guard let idx = model.draft.captionWithDesc.firstIndex(where: { $0.languageCode == old }) else {
            assertionFailure("We expect the given old language code to both have an existing caption and desc in the draft")
            return
        }

        model.draft.captionWithDesc[idx].languageCode = new
    }


    private var filenameSection: some View {
        Section {
            HStack {
                TextField("Filename", text: $model.draft.name, selection: $filenameSelection, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .focused($focus, equals: .filename)
                    .tint(.primary)
                    .padding(.trailing)
                Spacer(minLength: 0)
                if model.nameValidationResult == nil {
                    ProgressView()
                } else {
                    Button {
                        switch model.nameValidationResult {
                        case .success(_), .none:
                            // do nothing, alternatively, tell user, the full filename including name ending and
                            // that it was checked with the backend?
                            break
                        case .failure(_):
                            isFilenameErrorSheetPresented = true
                        }

                    } label: {
                        switch model.nameValidationResult {
                        case .failure(_), .none:
                            Image(systemName: "exclamationmark.circle")
                                .foregroundStyle(.red)
                        case .success(_):
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(.green)
                        }
                    }
                    .alert(
                        model.nameValidationResult?.alertTitle ?? "", isPresented: $isFilenameErrorSheetPresented, presenting: model.nameValidationResult?.error,
                        actions: { error in
                            if case .invalid(let localInvalidationError) = error,
                                localInvalidationError?.canBeAutoFixed == true,
                                model.draft.selectedFilenameType == .custom
                            {
                                Button("sanitize") {
                                    filenameSelection = .none
                                    model.draft.name = LocalFileNameValidation.sanitizeFileName(model.draft.name)
                                }
                            }
                            Button("Ok") {
                                let endIdx = model.draft.name.endIndex
                                focus = .filename
                                filenameSelection = .init(range: endIdx..<endIdx)
                            }
                        },
                        message: { error in
                            let failureReason = model.nameValidationResult?.error?.failureReason
                            let recoverySuggestion = model.nameValidationResult?.error?.recoverySuggestion

                            let isFailureReasonIdenticalToTitle = failureReason == model.nameValidationResult?.alertTitle
                            if let failureReason, let recoverySuggestion, !isFailureReasonIdenticalToTitle {
                                Text(failureReason + "\n\n\(recoverySuggestion)")
                            } else if let recoverySuggestion {
                                Text(recoverySuggestion)
                            }

                        }
                    )

                    .imageScale(.large)
                    .frame(width: 10)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .animation(.default, value: model.nameValidationResult?.error)

        } header: {
            Text("file name")
        } footer: {
            Menu {
                ForEach(model.suggestedFilenames, id: \.type) { suggested in
                    Button {
                        model.draft.selectedFilenameType = suggested.type
                        model.draft.name = suggested.name
                    } label: {
                        Text(suggested.name)
                        Text(suggested.type.description)
                    }

                }
            } label: {
                Label(
                    model.draft.selectedFilenameType.description,
                    systemImage: model.draft.selectedFilenameType.systemIconName
                )
            }


        }
        .task(id: model.draft.name) {
            // TODO: generate in model of name change
            var generatedSuggestions: [FileNameTypeTuple] = []
            for type in FileNameType.automaticTypes {
                let generatedFilename =
                    await type.generateFilename(
                        coordinate: model.exifData?.coordinate,
                        date: model.draft.inceptionDate,
                        desc: model.draft.captionWithDesc,
                        locale: Locale.current,
                        tags: model.draft.tags
                    )

                if let generatedFilename {
                    generatedSuggestions.append(
                        .init(
                            name: generatedFilename, type: type)
                    )
                }

            }

            model.suggestedFilenames = generatedSuggestions

            guard !model.draft.name.isEmpty else { return }

            let matchingAutomatic = generatedSuggestions.first(where: { suggestion in
                model.draft.name == suggestion.name
            })

            if let matchingAutomatic {
                model.draft.selectedFilenameType = matchingAutomatic.type
            } else {
                model.draft.selectedFilenameType = .custom
            }
        }

    }


    private var tagsSection: some View {
        Section {
            let tags: [TagItem] = model.draft.tags

            if !tags.isEmpty {

                HFlowLayout(alignment: .leading) {
                    ForEach(tags) { tag in
                        Button {
                            model.isShowingStatementPicker = true
                        } label: {
                            TagLabel(tag: tag)
                        }
                        .id(tag.id)
                    }
                    .buttonStyle(.plain)
                }
                .animation(.default, value: model.draft.tags)


            }

            Button(
                model.draft.tags.isEmpty ? "Add" : "Edit",
                systemImage: model.draft.tags.isEmpty ? "plus" : "pencil"
            ) {
                model.isShowingStatementPicker = true
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
                if model.exifData?.coordinate == nil {
                    // TODO: allow user to add own location
                    Label {
                        VStack(alignment: .leading) {
                            Text("No location")
                            Text("File metadata does not contain location info")
                                .font(.caption)
                        }
                    } icon: {
                        Image(systemName: "location.slash.fill")
                    }
                } else {
                    Toggle("Location", systemImage: model.draft.locationEnabled ? "location" : "location.slash", isOn: $model.draft.locationEnabled)
                        .animation(.default) {
                            $0.contentTransition(.symbolEffect)
                        }
                    if model.draft.locationEnabled == false {
                        Text("Location will be erased from the file metadata before uploading.")
                            .font(.caption)
                    } else if let coordinate = model.choosenCoordinate {
                        FileLocationMapView(coordinate: coordinate, label: locationLabel)
                    }
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
                    if let license = model.draft.license {
                        Text(license.abbreviation)
                    } else {
                        Text("choose")
                    }
                }
                .focused($focus, equals: .license)

            }
            .sheet(isPresented: $isLicensePickerShowing) {
                LicensePicker(selectedLicense: $model.draft.license)
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
    var imageView: some View {
        // we only expect the model.fileItem?.fileURL, but thumburl is useful for previews
        Button {
            isZoomableImageViewerPresented = true
        } label: {
            LazyImage(request: model.imageRequest) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .transition(.blurReplace)
                        .clipShape(.containerRelative)
                } else {
                    Color.clear.background(.regularMaterial)
                }
            }
        }
        .buttonStyle(ImageButtonStyle())
        .containerRelativeFrame(.horizontal)
        .listRowInsets(.init())
        .listRowBackground(Color.clear)
        .zoomableImageFullscreenCover(
            imageReference: model.zoomableImageReference,
            isPresented: $isZoomableImageViewerPresented
        )
    }

    private var dateTimeSection: some View {
        Section("Creation Date and Time") {
            DatePicker(
                "Creation Date",
                selection: $model.draft.inceptionDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)

            //            HStack {
            //                // TODO: extend this, atleast with a helper text
            //                // about what is ok to upload and what not.
            //
            //                Text("Timezone")
            //                Spacer()
            //
            //                Button {
            //                    isTimezonePickerShowning = true
            //                } label: {
            //                    if let timezoneId = model.draft.timezone,
            //                        let timezone = TimeZone(identifier: timezoneId)
            //                    {
            //                        VStack {
            //                            Text(timezone.identifier)
            //
            //                            if let tzName = timezone.localizedName(for: .standard, locale: .autoupdatingCurrent) {
            //                                Text(tzName)
            //                                    .font(.footnote)
            //                            }
            //                        }
            //                    } else {
            //                        Label("empty", systemImage: "pencil")
            //                    }
            //                }
            //
            //            }

            if let exifDate = model.exifData?.dateOriginal, model.draft.inceptionDate != exifDate {
                Button("Restore EXIF-Date") {
                    model.draft.inceptionDate = exifDate
                }
            }

        }
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
            if model.draft.uploadPossibleStatus == .uploadPossible {
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
                        uploadManager.upload(model.draft, username: username)
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
                            switch model.draft.uploadPossibleStatus {
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
                        switch model.draft.uploadPossibleStatus {
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

struct FileLocationMapView: View {
    let coordinate: CLLocationCoordinate2D
    var label: String?

    @State private var markerLabel: String?

    var body: some View {
        let halfKmRadius = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 500,
            longitudinalMeters: 500
        )

        Map(initialPosition: .region(halfKmRadius)) {
            Marker(label ?? "", coordinate: coordinate)
        }
        .mapControlVisibility(.automatic)
        .allowsHitTesting(false)
        .frame(height: 150)
        .clipShape(.rect(cornerRadius: 15))


    }
}

struct LanguageButtons: View {
    let disabledLanguages: [LanguageCode]
    let onSelect: (WikimediaLanguage) -> Void

    var body: some View {
        ForEach(WikimediaLanguage.all) { language in
            Button(language.localizedDescription) {
                onSelect(language)
            }
            .disabled(disabledLanguages.contains(language.code))
        }
    }
}

/// Allows the set the text for caption and description per languageCode via direct binding
extension [MediaFileDraft.DraftCaptionWithDescription] {
    fileprivate enum FieldType {
        case caption
        case description
    }

    fileprivate subscript(code: LanguageCode, field: FieldType) -> String {
        get {
            switch field {
            case .caption:
                first(where: { $0.languageCode == code })?.caption ?? ""
            case .description:
                first(where: { $0.languageCode == code })?.fullDescription ?? ""
            }
        }

        set {
            if let idx = firstIndex(where: { $0.languageCode == code }) {
                switch field {
                case .caption: self[idx].caption = newValue
                case .description: self[idx].fullDescription = newValue
                }
            } else {
                logger.warning("unusually setting a description or caption via Binding that didn't exist yet. \(nil)")
                append(.init(caption: newValue, languageCode: code))
            }
        }
    }
}

#Preview("New Draft", traits: .previewEnvironment) {
    @Previewable @State var draft = MediaFileDraftModel(existingDraft: .makeRandomEmptyDraft(id: "1"))

    SingleImageDraftView(model: draft)
}

#Preview("With Metadata", traits: .previewEnvironment) {
    @Previewable @State var draft = MediaFileDraftModel(existingDraft: .makeRandomDraft(id: "2"))

    SingleImageDraftView(model: draft)

}
