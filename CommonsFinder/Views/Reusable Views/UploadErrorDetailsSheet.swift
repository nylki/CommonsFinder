//
//  UploadErrorDetailsSheet.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 02.10.25.
//

import CommonsAPI
import SwiftUI

extension View {
    @ViewBuilder
    func uploadErrorDetailsSheet(
        _ status: UploadStatus?,
        isPresented: Binding<Bool>,
        onEditDraft: @escaping () -> Void,
        onDeleteDraft: @escaping () -> Void
    ) -> some View {
        modifier(UploadErrorDetailsSheetModifier(status: status, isPresented: isPresented, onEditDraft: onEditDraft, onDeleteDraft: onDeleteDraft))
    }
}

private struct UploadErrorDetailsSheetModifier: ViewModifier {
    let status: UploadStatus?
    @Binding var isPresented: Bool
    let onEditDraft: () -> Void
    let onDeleteDraft: () -> Void
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                NavigationStack {
                    UploadErrorDetailsSheet(status: status, onEditDraft: onEditDraft, onDeleteDraft: onDeleteDraft)
                }
                .presentationDetents([.fraction(0.33), .medium])
            }
    }
}

private struct UploadErrorDetailsSheet: View {
    let status: UploadStatus?
    let onEditDraft: () -> Void
    let onDeleteDraft: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {

        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading) {
                    switch status {
                    case .uploadWarnings(let warnings):
                        ForEach(warnings) { warning in
                            HStack {
                                Text("•")
                                Text(warning.localizedStringResource)
                            }
                            .padding(.bottom, 5)
                        }
                    case .error(let errorDescription, let recoverySuggestion):

                        Text(errorDescription ?? "Unknown Error")
                            .padding(.bottom, 5)

                        if let recoverySuggestion {
                            HStack {
                                Text("• What can you do?")
                                Text(recoverySuggestion)
                            }
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
                    case .published, .uploading(_), .unstashingFile, .creatingWikidataClaims:
                        // TODO: maybe as a spin to a feature, instead of awkwardly handling this edge case, allow this dialog for just uploaded files, to see more info and adjust the messaging (green checkmark instead of yellow triangle etc.)?
                        Text("If you see this error dialog, please file a bugreport for the app, thanks! You file appears to still being uploaded or succesfully uploaded and this should not appear.")
                            .onAppear {
                                assertionFailure("Don't show error for non-error status!")
                            }


                    }

                    Spacer(minLength: 0)
                }
            }

            .scenePadding([.horizontal, .top])
            .navigationBarTitle("", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .title) {
                    Text("\(Image(systemName: "square.and.arrow.up.trianglebadge.exclamationmark.fill")) Upload Error")
                        .bold()
                        .symbolRenderingMode(.multicolor)

                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark", role: .cancel, action: dismiss.callAsFunction)
                }


                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete", systemImage: "trash", role: .destructive, action: onDeleteDraft)
                }

                ToolbarItem(placement: .automatic) {
                    Button("Edit", systemImage: "square.and.pencil", action: onEditDraft)
                }
            }
        }


    }
}

#Preview("multiple warnings") {
    @Previewable @State var isPresented = true
    Button("show error sheet") {
        isPresented = true
    }
    .glassButtonStyle()
    .uploadErrorDetailsSheet(
        .uploadWarnings([.duplicate, .badfilename]),
        isPresented: $isPresented,
        onEditDraft: {},
        onDeleteDraft: {}
    )
}


#Preview("single warning") {
    @Previewable @State var isPresented = true
    Button("show error sheet") {
        isPresented = true
    }
    .glassButtonStyle()
    .uploadErrorDetailsSheet(
        .uploadWarnings([.duplicate]),
        isPresented: $isPresented,
        onEditDraft: {},
        onDeleteDraft: {}
    )
}

#Preview("long error") {
    @Previewable @State var isPresented = true
    Button("show error sheet") {
        isPresented = true
    }
    .glassButtonStyle()
    .uploadErrorDetailsSheet(
        .twoFactorCodeRequired,
        isPresented: $isPresented,
        onEditDraft: {},
        onDeleteDraft: {}
    )
}

#Preview("unspecified error") {
    @Previewable @State var isPresented = true
    Button("show error sheet") {
        isPresented = true
    }
    .glassButtonStyle()
    .uploadErrorDetailsSheet(
        .error(errorDescription: PreviewDebugError.httpRequestDenied.localizedDescription, recoverySuggestion: nil),
        isPresented: $isPresented,
        onEditDraft: {},
        onDeleteDraft: {}
    )
}


enum PreviewDebugError: Error {
    case httpRequestDenied
}
