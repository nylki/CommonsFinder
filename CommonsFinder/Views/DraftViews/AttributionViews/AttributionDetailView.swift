//
//  AttributionDetailView.swift
//  CommonsFinder
//
//  Created by Tom on 25.10.26.
//

import SwiftUI
import TipKit

@Observable private final class OtherPersonAttribution {
    var customAuthorName: String = ""
    var customAuthorWikimediaUsername: String = ""
    var customAuthorURL: URL?
    var customSourceString: String = ""
    var customLicenseString: String = ""

    var draftLicense: DraftMediaLicense?

    var draftSource: DraftSource? {
        DraftSource.otherSource(customSourceString)
    }
    var draftAuthor: DraftAuthor? {
        if let customAuthor {
            DraftAuthor.custom(author: customAuthor)
        } else {
            .unknown
        }
    }

    private var customAuthor: DraftAuthor.CustomAuthor? {
        if !customAuthorName.isEmpty {
            let username = customAuthorWikimediaUsername.isEmpty ? nil : customAuthorWikimediaUsername
            return .init(name: customAuthorName, wikimediaUsername: username, url: customAuthorURL)
        } else {
            return .none
        }
    }


    init(initialSource: DraftSource?, initialAuthor: DraftAuthor?, initialLicense: DraftMediaLicense?) {
        switch initialSource {
        case .own, .selfPhotographed, nil:
            // use default values
            break
        case .otherSource(let string):
            customSourceString = string

            if let customAuthor = initialAuthor?.customAuthor {
                customAuthorName = customAuthor.name
                customAuthorWikimediaUsername = customAuthor.wikimediaUsername ?? ""
                customAuthorURL = customAuthor.url
            }

            if case .custom(let wikitext) = initialLicense {
                customLicenseString = wikitext
                draftLicense = .custom(wikitext: "")
            } else {
                draftLicense = initialLicense
            }
        }
    }
}

@Observable private final class MeAttribution {
    // only the license is changeable here:
    var draftLicense: DraftMediaLicense?

    let draftAuthor: DraftAuthor?
    let draftSource: DraftSource?

    init(initialSource: DraftSource?, initialAuthor: DraftAuthor?, initialLicense: DraftMediaLicense?) {
        switch initialSource {
        case .own, .selfPhotographed:
            self.draftSource = initialSource
            self.draftAuthor = initialAuthor
            self.draftLicense = initialLicense
        case .otherSource, nil:
            self.draftSource = .own  // or .selfPhotographed
            self.draftAuthor = .appUser
            self.draftLicense = UserDefaults.standard.defaultPublishingLicense
        }
    }
}

private enum SourceOption {
    case me
    case other
}


struct AttributionDetailView: View {
    // TODO: let draftable: Draftable for simpler init
    let initialSource: DraftSource?
    let initialAuthor: DraftAuthor?
    let initialLicense: DraftMediaLicense?

    let onConfirm: (_ source: DraftSource?, _ author: DraftAuthor?, _ license: DraftMediaLicense?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var isLicensePickerShowing = false
    @State private var sourceOption: SourceOption?

    @State private var meAttribution: MeAttribution?
    @State private var otherPersonAttribution: OtherPersonAttribution?

    private func confirmChanges() {
        switch sourceOption {
        case .me:
            onConfirm(
                meAttribution?.draftSource,
                meAttribution?.draftAuthor,
                meAttribution?.draftLicense
            )
        case .other:
            onConfirm(
                otherPersonAttribution?.draftSource,
                otherPersonAttribution?.draftAuthor,
                otherPersonAttribution?.draftLicense
            )
        case .none:
            break
        }

        dismiss()
    }

    @ViewBuilder
    private var meSourceForm: some View {
        if let meAttribution {
            @Bindable var model = meAttribution

            Section("What free license do you want to publish your work under?") {
                HStack {
                    Text("License")
                    Spacer()
                    Button {
                        isLicensePickerShowing = true
                    } label: {
                        if let license = model.draftLicense {
                            Text(license.abbreviation)
                        } else {
                            Text("choose")
                        }
                    }
                }
                .sheet(isPresented: $isLicensePickerShowing) {
                    LicensePicker(selectedLicense: $model.draftLicense, allowsEmptySelection: false)
                }
            }
        }

    }

    @ViewBuilder
    private var otherSourceForm: some View {
        if let otherPersonAttribution {
            @Bindable var model = otherPersonAttribution
            Section("Were did you find this work?") {

                TextField("URL, book or another source", text: $model.customSourceString)
                    .textInputAutocapitalization(.never)

            }

            Section("Enter the name of the original author of these works:") {
                TextField("John Doe", text: $model.customAuthorName)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
            }

            Section("Do you know the license the creator published this work under?") {
                Picker("License", selection: $model.draftLicense) {
                    ForEach(DraftMediaLicense.originalChoices, id: \.rawValue) { license in
                        Text(license.abbreviation).tag(Optional(license))
                    }
                    Text("Other license").tag(Optional(DraftMediaLicense.custom(wikitext: "")))
                    Text("I don't know").tag(DraftMediaLicense?.none)
                }

                switch model.draftLicense {
                case .custom:
                    // TODO: auto-add curly braces (when evaluating)
                    TextField("License template, eg. {{cc-by-2.0}}", text: $model.customLicenseString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                case .none:
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Do not upload this file unless you are certain of the license under which it was published.")
                        }
                        Link(destination: URL(string: "https://commons.m.wikimedia.org/wiki/Commons:Licensing#Acceptable licenses")!) {
                            Label("Learn more about what is permitted", systemImage: "info.circle")
                        }

                        .padding(.top)
                    }

                default:
                    EmptyView()
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            TipView(AttributionIntroTip(isAutoPatrolUser: false))
                .padding(.bottom)
            Form {
                Section("Who created this work?") {
                    Picker(selection: $sourceOption) {
                        Text("me").tag(SourceOption.me)
                        Text("someone else").tag(SourceOption.other)
                    } label: {
                        Text("Who created this work?")
                    }
                    .pickerStyle(.palette)
                }
                .listRowBackground(Color.clear)

                switch sourceOption {
                case .me: meSourceForm
                case .other: otherSourceForm
                case .none: EmptyView()
                }
            }

            .animation(.default, value: sourceOption)
            .task {
                guard sourceOption == nil else { return }
                switch initialSource {
                case .own, .selfPhotographed:
                    sourceOption = .me
                case .otherSource:
                    sourceOption = .other
                case nil:
                    sourceOption = .me
                }

                meAttribution = .init(initialSource: initialSource, initialAuthor: initialAuthor, initialLicense: initialLicense)
                otherPersonAttribution = .init(initialSource: initialSource, initialAuthor: initialAuthor, initialLicense: initialLicense)
            }
            .navigationTitle("Attribution & License")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel", systemImage: "xmark", role: .cancel, action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("confirm", systemImage: "checkmark", role: .fallbackConfirm, action: confirmChanges)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled()
    }


}

#Preview {
    @Previewable @State var isPresented = true
    @Previewable @State var source: DraftSource? = .own
    @Previewable @State var author: DraftAuthor? = .appUser
    @Previewable @State var license: DraftMediaLicense? = .CC0_1_0

    VStack {
        switch source {
        case .own:
            Text("Own file - created by you, the user")
        case .selfPhotographed:
            Text("self photographed - photographed by you, the user, may contain works by others in the photograph")
        case .otherSource(let string):
            if !string.isEmpty {
                Text("file from somewhere else: \(string)")
            } else {
                Text(
                    "file from somwhere else, missing a source URL. you must provide a valid URL. The source must have a compatible free license (eg. creative commons licenses like CC0 or CC-BY and CC-BY SA)"
                )
            }
        case .none:
            Text("none")
        }
        Button("open") {
            isPresented = true
        }
        .sheet(isPresented: $isPresented) {

            AttributionDetailView(initialSource: source, initialAuthor: author, initialLicense: license) { newSource, newAuthor, newLicense in
                source = newSource
                author = newAuthor
                license = newLicense
            }
        }
    }
}
