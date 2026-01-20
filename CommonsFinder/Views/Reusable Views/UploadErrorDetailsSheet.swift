//
//  PublishingErrorDetailsSheet.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 02.10.25.
//


import CommonsAPI
import SwiftUI
import os.log

extension View {
    @ViewBuilder
    func publishingErrorDetailsSheet(
        _ publishingStatus: PublishingState?,
        _ error: PublishingError?,
        isPresented: Binding<Bool>,
        onEditDraft: @escaping () -> Void,
        onDeleteDraft: @escaping () -> Void,
        onContinueUpload: @escaping () -> Void
    ) -> some View {
        modifier(
            PublishingErrorDetailsSheetModifier(
                publishingStatus: publishingStatus,
                error: error,
                isPresented: isPresented,
                onEditDraft: onEditDraft,
                onDeleteDraft: onDeleteDraft,
                onContinueUpload: onContinueUpload
            )
        )
    }
}

private struct PublishingErrorDetailsSheetModifier: ViewModifier {
    let publishingStatus: PublishingState?
    let error: PublishingError?
    @Binding var isPresented: Bool
    let onEditDraft: () -> Void
    let onDeleteDraft: () -> Void
    let onContinueUpload: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                NavigationStack {
                    PublishingErrorDetailsSheet(
                        publishingStatus: publishingStatus,
                        error: error,
                        onEditDraft: onEditDraft,
                        onDeleteDraft: onDeleteDraft,
                        onContinueUpload: onContinueUpload
                    )
                }
                .presentationDetents([.medium, .large])
            }
    }
}

private struct PublishingErrorDetailsSheet: View {
    let publishingStatus: PublishingState?
    let error: PublishingError?

    let onEditDraft: () -> Void
    let onDeleteDraft: () -> Void
    let onContinueUpload: () -> Void

    @Environment(UploadManager.self) private var uploadManager

    private var isContinuationPossible: Bool {
        return switch error {
        case .twoFactorCodeRequired, .emailCodeRequired:
            true
        case .uploadWarnings(let warnings):
            if warnings.contains(.duplicate) || warnings.contains(.duplicateArchive) {
                false
            } else {
                true
            }
        case .appQuitOrCrash:
            true
        case .urlError(_, _):
            true
        case .error(_, _):
            true
        case nil:
            true
        }
    }

    private var isEditingPossible: Bool {
        return switch publishingStatus {
        case .uploading(_):
            true
        case .uploaded(_):
            true
        case .unstashingFile(_):
            true
        case .creatingWikidataClaims:
            false
        case .published:
            false
        case nil:
            true
        }
    }

    @Environment(\.dismiss) private var dismiss
    var body: some View {

        NavigationStack {
            ScrollView {
                detailsList
            }
            .safeAreaInset(edge: .bottom) {
                bottomButtons
            }
            .scenePadding([.horizontal, .top])
            .navigationBarTitle("", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .title) {
                    Text("\(Image(systemName: "square.and.arrow.up.trianglebadge.exclamationmark.fill")) Upload Error")
                        .bold()
                        .symbolRenderingMode(.multicolor)
                        .foregroundStyle(.primary)
                }
                if !uploadManager.isVerifyingErrorDrafts {
                    ToolbarItem {
                        Menu("More…", systemImage: "ellipsis") {
                            if isEditingPossible {
                                Button("Edit Draft", systemImage: "square.and.pencil", action: onEditDraft)
                            }
                            Button("Delete Draft", systemImage: "trash", role: .destructive, action: onDeleteDraft)
                        }
                    }

                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark", role: .cancel, action: dismiss.callAsFunction)
                    }
                }
            }
        }
        .onAppear {
            uploadManager.verifyDraftsWithErrors()
        }


    }

    @ViewBuilder
    private var detailsList: some View {
        VStack {
            //            GroupBox(label: Label("Last Status", systemImage: "info.circle")) {
            //                HStack {
            //                    switch publishingStatus {
            //                    case .uploading(let fractionCompleted):
            //                        Text("The data upload was interrupted at \(Int(fractionCompleted * 100))%.")
            //                    case .uploaded(_), .unstashingFile(_):
            //                        Text("File was uploaded, but is still **un-published** and also **missing structured metadata**.")
            //                    case .creatingWikidataClaims:
            //                        Text("file was uploaded and published. Captions and other structured metadata are not yet created though.")
            //                    case .published, nil:
            //                        EmptyView()
            //                    }
            //                    Spacer(minLength: 0)
            //                }
            //                .padding(5)
            //
            //            }


            GroupBox {
                HStack {
                    switch error {
                    case .appQuitOrCrash:
                        Text("The app was closed or crashed while uploading.")
                    case .uploadWarnings(let warnings):
                        ForEach(warnings) { warning in
                            Text(warning.localizedStringResource)
                                .padding(.bottom)
                        }
                    case .urlError(let urlErrorCode, let errorDescription):
                        let errorCode = URLError.Code(rawValue: urlErrorCode)

                        switch errorCode {
                        case .networkConnectionLost: Text("Network connection lost")
                        case .badServerResponse: Text("Bad server response")
                        case .notConnectedToInternet: Text("not connected To the Internet")
                        case .dataLengthExceedsMaximum: Text("Data-length exceeds maximum")
                        case .secureConnectionFailed: Text("Secure connection failed")
                        case .timedOut: Text("Network Connection timed out")
                        case .dnsLookupFailed: Text("DNS Lookup Failed")
                        case .userAuthenticationRequired: Text("User authentication required")
                        default: Text(errorDescription)
                        }

                    case .error(let errorDescription, _):

                        Text(errorDescription ?? "Unknown Error")
                            .padding(.bottom, 5)
                    case .emailCodeRequired, .twoFactorCodeRequired:
                        Text(
                            "Authentication failed: 2-factor code required"
                        )
                    case .none:
                        Text("There may have been a problem during upload, but no details can be display. Please report this as a Bug in the app, thanks!")

                    }

                    Spacer(minLength: 0)
                }
                .monospaced()
                .padding(5)

            } label: {
                switch publishingStatus {
                case .uploading(let fractionCompleted):
                    Label("Data upload interrupted at \(Int(fractionCompleted * 100))%", systemImage: "exclamationmark.triangle")
                case .uploaded(_), .unstashingFile(_):
                    Label("File uploaded, but not yet public (stashed) and missing structured data", systemImage: "exclamationmark.triangle")
                case .creatingWikidataClaims:
                    Label("file was uploaded and published. Captions and other structured metadata are not yet created though", systemImage: "exclamationmark.triangle")
                case .published, nil:
                    Label("", systemImage: "exclamationmark.triangle")
                }
            }


            GroupBox(label: Label("What can you do?", systemImage: "info.bubble")) {
                HStack {
                    switch error {
                    case .appQuitOrCrash:
                        Text("You may attempt to retry the upload.")
                    case .uploadWarnings(let warnings):
                        if warnings.contains(.duplicate) || warnings.contains(.duplicateArchive) {
                            Text("Either you or somebody already uploaded this file in the past. You may remove the draft.")
                        }
                    case .urlError(let urlErrorCode, _):
                        let errorCode = URLError.Code(rawValue: urlErrorCode)

                        switch errorCode {
                        case .cannotConnectToHost, .cannotFindHost, .badServerResponse:
                            Text("The server appears to be currently down or experiencing maintenance issues, try again later to resume the upload.")
                        case .networkConnectionLost, .timedOut, .notConnectedToInternet:
                            Text("Retry and continue the upload when you have a stable internet connection.")
                        default:
                            Text(
                                "If your internet connection is unreliable or expensive at the moment try to continue the upload later. Otherwise please check if you can reach and login to Wikimedia Commons in a regular browser."
                            )
                        }

                    case .error(_, let recoverySuggestion):
                        if let recoverySuggestion {
                            Text(recoverySuggestion)
                        } else {
                            Text("You may attempt to retry the upload, edit the draft or delete the draft.")
                        }
                    case .emailCodeRequired, .twoFactorCodeRequired:
                        Text(
                            "Your account requires a 2-factor code to authenticate.\nYou may have added this security step recently after you added your account to the app. Currently this requires you to fully logout and re-login in the app, sorry for the inconvenience!"
                        )
                    case .none:
                        Text("There may have been a problem during upload, but no details can be display. Please report this as a Bug in the app, thanks!")
                    }
                    Spacer(minLength: 0)
                }
                .padding(5)
            }

        }


    }

    @ViewBuilder
    private var bottomButtons: some View {
        if uploadManager.isVerifyingErrorDrafts {
            ProgressView().progressViewStyle(.circular)
        } else {
            if isContinuationPossible {
                Button(action: onContinueUpload) {
                    Label(
                        publishingStatus == .creatingWikidataClaims ? "Finish Details" : "Retry Upload",
                        systemImage: "arrow.trianglehead.2.clockwise.rotate.90"
                    )
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .padding(10)
                }
                .glassButtonStyle(prominent: true)
            } else {
                Button(role: .destructive, action: onDeleteDraft) {
                    Label("Delete Draft", systemImage: "trash")
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .padding(10)
                        .foregroundStyle(.red)
                }
                .glassButtonStyle()
            }
        }
    }
}

#Preview("network error", traits: .previewEnvironment) {
    @Previewable @State var isPresented = true
    Button("show error sheet") {
        isPresented = true
    }
    .glassButtonStyle()
    .publishingErrorDetailsSheet(
        .uploading(0.4),
        .urlError(urlErrorCode: URLError.Code.badServerResponse.rawValue, errorDescription: "This is just debug error description text, the real one would come from an action request."),
        isPresented: $isPresented,
        onEditDraft: {},
        onDeleteDraft: {},
        onContinueUpload: {}
    )
}
#Preview("multiple warnings", traits: .previewEnvironment) {
    @Previewable @State var isPresented = true
    Button("show error sheet") {
        isPresented = true
    }
    .glassButtonStyle()
    .publishingErrorDetailsSheet(
        .uploaded(filekey: "abc"),
        .uploadWarnings([.duplicate, .badfilename]),
        isPresented: $isPresented,
        onEditDraft: {},
        onDeleteDraft: {},
        onContinueUpload: {}
    )
}


#Preview("single warning", traits: .previewEnvironment) {
    @Previewable @State var isPresented = true
    Button("show error sheet") {
        isPresented = true
    }
    .glassButtonStyle()
    .publishingErrorDetailsSheet(
        .uploaded(filekey: "abc"),
        .uploadWarnings([.duplicate]),
        isPresented: $isPresented,
        onEditDraft: {},
        onDeleteDraft: {},
        onContinueUpload: {}
    )
}

#Preview("long error", traits: .previewEnvironment) {
    @Previewable @State var isPresented = true
    Button("show error sheet") {
        isPresented = true
    }
    .glassButtonStyle()
    .publishingErrorDetailsSheet(
        .uploading(0.0),
        .twoFactorCodeRequired,
        isPresented: $isPresented,
        onEditDraft: {},
        onDeleteDraft: {},
        onContinueUpload: {}
    )
}

#Preview("unspecified error", traits: .previewEnvironment) {
    @Previewable @State var isPresented = true
    Button("show error sheet") {
        isPresented = true
    }
    .glassButtonStyle()
    .publishingErrorDetailsSheet(
        .uploading(0.0),
        .error(errorDescription: PreviewDebugError.httpRequestDenied.localizedDescription, recoverySuggestion: nil),
        isPresented: $isPresented,
        onEditDraft: {},
        onDeleteDraft: {},
        onContinueUpload: {}
    )
}


enum PreviewDebugError: Error {
    case httpRequestDenied
}
