//
//  FilenameErrorButton.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 25.03.26.
//


import SwiftUI

struct FilenameErrorButton: View {
    let nameValidationResult: NameValidationResult
    let fileNameType: FileNameType
    
    let onDismiss: () -> Void
    let onSanitize: () -> Void
    
    @State private var isFilenameAlertPresented = false
    
    var body: some View {
        Button {
            switch nameValidationResult {
            case .success(_):
                // do nothing, alternatively, tell user, the full filename including name ending and
                // that it was checked with the backend?
                break
            case .failure(_):
                isFilenameAlertPresented = true
            }

        } label: {
            switch nameValidationResult {
            case .failure(_):
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(.red)
            case .success(_):
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)
            }
        }
        .alert(
            nameValidationResult.alertTitle ?? "",
            isPresented: $isFilenameAlertPresented,
            presenting: nameValidationResult.error,
            actions: { error in
                if case .invalid(let localInvalidationError) = error,
                   let localInvalidationError, localInvalidationError.canBeAutoFixed == true,
                   fileNameType == .custom {
                    Button("sanitize", action: onSanitize)
                }
                Button("Ok", action: onDismiss)
            },
            message: { error in
                let failureReason = nameValidationResult.error?.failureReason
                let recoverySuggestion = nameValidationResult.error?.recoverySuggestion

                let isFailureReasonIdenticalToTitle = failureReason == nameValidationResult.alertTitle
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
