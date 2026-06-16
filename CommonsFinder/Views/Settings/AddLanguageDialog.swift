//
//  AddLanguageDialog.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 16.06.26.
//

import SwiftUI

struct AddLanguageDialog: View {
    let alreadyChoosenLanguages: Set<Locale.LanguageCode>
    let onLanguageChoosen: (Locale.LanguageCode) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var searchString = ""

    private let isoLanguageCodes = Locale.LanguageCode.isoLanguageCodes.sorted(by: \.identifier, .orderedAscending)

    private var filteredLanguageCodes: [Locale.LanguageCode] {
        if searchString.isEmpty {
            isoLanguageCodes
        } else {
            isoLanguageCodes.filter { code in
                code.identifier.localizedStandardContains(searchString) || code.localizedLanguageName.localizedStandardContains(searchString)
            }
        }


    }

    var body: some View {
        NavigationStack {
            List(filteredLanguageCodes) { languageCode in
                let isAlreadyUsed = alreadyChoosenLanguages.contains(languageCode)

                Button {
                    onLanguageChoosen(languageCode)
                    dismiss()
                } label: {
                    HStack {
                        Text(languageCode.localizedLanguageName)

                        Spacer()

                        Image(systemName: "checkmark")
                            .opacity(isAlreadyUsed ? 1 : 0)
                            .foregroundStyle(.green)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close", systemImage: "xmark", action: dismiss.callAsFunction)
                }
            }
            .searchable(text: $searchString)
            .toolbarTitleDisplayMode(.inline)
            .navigationTitle("Add a Language")
        }


    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        AddLanguageDialog(alreadyChoosenLanguages: [.english, .ainu]) {
            print($0.localizedLanguageName)
        }
    }
}
