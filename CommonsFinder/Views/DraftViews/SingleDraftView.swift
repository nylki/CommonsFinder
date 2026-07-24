//
//  MetadataEditForm.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 13.10.24.
//

import CommonsAPI
import Foundation
import FrameUp
@preconcurrency import MapKit
import NukeUI
import OrderedCollections
import SwiftUI
import TipKit
import UniformTypeIdentifiers
import os.log

struct SingleDraftView: View {
    @Bindable var model: SingleDraftModel

    @Environment(WikimediaLanguageStore.self) private var languageStore
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
        IndividualDraftForm(model: model, withImage: true)
            .toolbar { toolbarContent }
    }

    private func saveChangesAndDismiss() {
        model.saveChanges(appDatabase: appDatabase)
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
            if let username = account.activeUser?.username, model.draft.uploadPossibleStatus == .uploadPossible {
                Button {
                    isShowingUploadDialog = true
                } label: {
                    Label("Upload", systemImage: "arrow.up")
                }
                .confirmationDialog("Start upload to Wikimedia Commons now?", isPresented: $isShowingUploadDialog, titleVisibility: .visible) {
                    Button("Upload", systemImage: "square.and.arrow.up", role: .fallbackConfirm) {
                        model.saveChanges(appDatabase: appDatabase)
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
                        if account.activeUser == nil {
                            Text("You must be logged in to a Wikimedia account to upload files.")
                        } else {
                            switch model.draft.uploadPossibleStatus {
                            case .uploadPossible:
                                Text("Unknown error, please make a screenshot and report this issue if you see this.")
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
                        }
                    })
            }
        }


    }
}


#Preview("New Draft", traits: .previewEnvironment) {
    @Previewable @State var draft = SingleDraftModel(existingDraft: .makeRandomEmptyDraft(id: "1"))

    SingleDraftView(model: draft)
}

#Preview("With Metadata", traits: .previewEnvironment) {
    @Previewable @State var draft = SingleDraftModel(existingDraft: .makeRandomDraft(id: "2"))

    SingleDraftView(model: draft)

}
