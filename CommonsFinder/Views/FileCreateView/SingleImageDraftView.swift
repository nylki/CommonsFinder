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
import os.log

struct SingleImageDraftView: View {
    @Bindable var model: MediaFileDraftModel

    @Environment(\.openURL) private var openURL
    @Environment(\.locale) private var locale
    @FocusState private var focus: FocusElement?

    @State private var selectedFilenameType: FileNameType = .captionAndDate
    @State private var filenameSelection: TextSelection?
    @State private var isLicensePickerShowing = false
    @State private var isTimezonePickerShowning = false
    @State private var locationLabel: String?
    @State private var isZoomableImageViewerPresented = false

    private enum FocusElement: Hashable {
        case title
        case caption
        case description
        case categories
        case filename
    }

    var body: some View {
        Form {
            imageView
            captionAndDescriptionSection
            statementsSection
            locationSection
            attributionSection
            dateTimeSection
            filenameSection
        }
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
        .sheet(isPresented: $isTimezonePickerShowning) {
            TimezonePicker(selectedTimezone: $model.draft.timezone)
                .presentationDetents([.medium, .large])
        }
        .onAppear {
            if model.draft.captionWithDesc.isEmpty {
                focus = .caption
            }
        }
        .onChange(of: model.draft) {
            generateFilename()
        }
        .onChange(of: selectedFilenameType) { oldValue, newValue in
            filenameSelection = .none
            if newValue == .custom, oldValue != .custom {
                focus = .filename
                let currentName = model.draft.name
                let startIdx = currentName.startIndex
                let endIdx = currentName.endIndex
                filenameSelection = .init(range: startIdx..<endIdx)
            } else {
                generateFilename()
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
                await selectedFilenameType.generateFilename(
                    coordinate: model.exifData?.coordinate,
                    date: model.draft.inceptionDate,
                    desc: model.draft.captionWithDesc,
                    locale: locale,
                    tags: model.draft.tags
                ) ?? model.draft.name

            model.draft.name = generatedFilename
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
                            focus = .categories
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
            Picker("filename", selection: $selectedFilenameType) {
                ForEach(FileNameType.allCases, id: \.self) { type in
                    Text(type.description)
                }
            }
            TextField("Filename", text: $model.draft.name, selection: $filenameSelection, axis: .vertical)
                .foregroundStyle(Color.primary.opacity(selectedFilenameType == .custom ? 1 : 0.75))
                .textInputAutocapitalization(.sentences)
                .focused($focus, equals: .filename)
                .disabled(selectedFilenameType != .custom)

            if selectedFilenameType == .custom {
                TipView(FilenameTip(), arrowEdge: .top) { action in
                    openURL(.commonsWikiFileNaming)
                }
            }
        } header: {
            Label("file name", systemImage: "character.cursor.ibeam")

        }
    }


    private var statementsSection: some View {
        Section {
            let tags: [TagItem] = model.draft.tags

            if !tags.isEmpty {
                HFlowLayout(alignment: .leading) {
                    ForEach(tags) { tag in
                        TagLabel(tag: tag)
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
                withAnimation {
                    model.isShowingStatementPicker = true
                }
            }
        } header: {
            Label("Tags", systemImage: "tag")
                .id("tags")
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
