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
                VStack(alignment: .leading, spacing: 20) {
                    switch publishingStatus {
                    case .uploading(let fractionCompleted):
                        Text("The data upload was interrupted at \(Int(fractionCompleted * 100))%.")
                    case .uploaded(_), .unstashingFile(_):
                        Text("An error occured after the file was uploaded. It is still un-published and missing metadata.")
                    case .creatingWikidataClaims:
                        Text("An error occured after the file was published. Captions and other structured metadata are missing and may still be created.")
                    case .published, nil:
                        EmptyView()
                    }

                    switch error {
                    case .appQuitOrCrash:
                        Text("The app was closed or crashed while uploading.")
                    case .uploadWarnings(let warnings):
                        ForEach(warnings) { warning in
                            HStack {
                                Text("•")
                                Text(warning.localizedStringResource)
                            }
                            .padding(.bottom, 5)
                        }
                        if warnings.contains(.duplicate) || warnings.contains(.duplicateArchive) {
                            Text("What can you do?")
                                .bold()
                            Text("Either you or somebody already uploaded this file in the past. You may remove the draft.")
                        }
                    case .urlError(let urlErrorCode, let errorDescription):
                        let errorCode = URLError.Code(rawValue: urlErrorCode)

                        HStack {
                            Text("•")
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
                        }
                        .padding(.bottom, 5)

                        Text("What can you do?")
                            .bold()
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

                    case .error(let errorDescription, let recoverySuggestion):

                        Text(errorDescription ?? "Unknown Error")
                            .padding(.bottom, 5)

                        if let recoverySuggestion {
                            Text("• What can you do?")
                            Text(recoverySuggestion)
                        }
                    case .emailCodeRequired, .twoFactorCodeRequired:
                        Text(
                            "Your account requires a 2-factor code to authenticate.\nYou may have added this security step recently after you added your account to the app. Currently this requires you to fully logout and re-login in the app, sorry for the inconvenience!"
                        )
                    //                    case .authenticationError(let error):
                    //                        // show a warning directly on the profile icon that there is an auth error, and requiring to (re)-authenticate with username/password etc.
                    //                        Text("There was a problem authenticating your user. There are a few different reasons why this could happen. Perhaps you recently changed your Wikimedia account credentials. \n You can retry the upload, otherwise check that you can login normally in the web and try to logout and re-login inside the app.")
                    //
                    //                        if let error {
                    //                            Text(error.localizedDescription)
                    //                        }
                    case .none:
                        Text("There may have been a problem during upload, but no details can be display. Please report this as a Bug in the app, thanks!")
                    }

                    Spacer(minLength: 0)
                }
            }
            .safeAreaInset(edge: .bottom) {

                if isContinuationPossible {
                    Button(action: onContinueUpload) {
                        if uploadManager.isVerifyingErrorDrafts {
                            ProgressView().progressViewStyle(.circular)
                        } else {
                            Group {
                                if publishingStatus == .creatingWikidataClaims {
                                    Label("Complete Details", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                                } else {
                                    Label("Retry Upload", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                                }
                            }
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .padding()
                        }
                    }
                    .glassButtonStyle()
                } else {
                    Button(action: onDeleteDraft) {
                        Label("Delete Draft", systemImage: "trash")
                    }
                }


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
        .onAppear {
            uploadManager.verifyDraftsWithErrors()
        }


    }
}

#Preview("network error") {
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
#Preview("multiple warnings") {
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


#Preview("single warning") {
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

#Preview("long error") {
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

#Preview("unspecified error") {
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
