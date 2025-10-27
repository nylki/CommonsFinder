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
    func uploadErrorDetailsSheet(_ status: UploadManagerStatus?, isPresented: Binding<Bool>) -> some View {
        modifier(UploadErrorDetailsSheetModifier(status: status, isPresented: isPresented))
    }
}

private struct UploadErrorDetailsSheetModifier: ViewModifier {
    let status: UploadManagerStatus?
    @Binding var isPresented: Bool
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                NavigationStack {
                    UploadErrorDetailsSheet(status: status)
                }
                .presentationDetents([.fraction(0.33), .medium])
            }
    }
}

private struct UploadErrorDetailsSheet: View {
    let status: UploadManagerStatus?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
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
                case .error(let localizedError):
                    Text(localizedError.localizedDescription)
                        .padding(.bottom, 5)
                    if let failureReason = localizedError.failureReason {
                        HStack {
                            Text("•")
                            Text(failureReason)
                        }
                    }
                    if let recoverySuggestion = localizedError.recoverySuggestion {
                        HStack {
                            Text("• What can you do?")
                            Text(recoverySuggestion)
                        }
                    }
                case .emailCodeRequired, .twoFactorCodeRequired:
                    Text(
                        "Your account requires a 2-factor code to authenticate.\nYou may have added this security step recently after you added your account to the app. Currently this requires you to fully logout and re-login in the app, sorry for the inconvenience!"
                    )
                case .unspecifiedError(let error):
                    // FIXME: emit .networkError from CommonsAPI directly
                    // with nicely formatted enum so we won't have to import AlamoFire here and be able to show better help messages (eg. check if wifi/network is available)
                    Text(error.localizedDescription)
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
                Button("Close", role: .fallbackClose, action: dismiss.callAsFunction)
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
        isPresented: $isPresented
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
        isPresented: $isPresented
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
        isPresented: $isPresented
    )
}

#Preview("unspecified error") {
    @Previewable @State var isPresented = true
    Button("show error sheet") {
        isPresented = true
    }
    .glassButtonStyle()
    .uploadErrorDetailsSheet(
        .unspecifiedError(PreviewDebugError.httpRequestDenied),
        isPresented: $isPresented
    )
}


enum PreviewDebugError: Error {
    case httpRequestDenied
}
