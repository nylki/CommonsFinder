//
//  AddLanguageDialog.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 16.06.26.
//

import SwiftUI

struct AddLanguageDialog: View {
    let alreadyChoosenLanguageCodes: Set<String>
    let onLanguageChoosen: (WikimediaLanguage) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(WikimediaLanguageStore.self) private var languageStore

    @State private var searchString = ""

    private var filteredLanguages: [WikimediaLanguage] {
        languageStore.query(searchString)
    }

    var body: some View {
        NavigationStack {
            List(filteredLanguages) { language in
                let isAlreadyUsed = alreadyChoosenLanguageCodes.contains(language.code)

                Button {
                    onLanguageChoosen(language)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(language.description)
                            if let autonym = language.autonym, autonym != language.description {
                                Text(autonym).foregroundStyle(.secondary)
                            }
                        }
                        .tint(.primary)

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

#Preview(traits: .previewEnvironment) {
    Color.clear.sheet(isPresented: .constant(true)) {
        AddLanguageDialog(alreadyChoosenLanguageCodes: ["en", "de"]) {
            print($0.description)
        }
    }
}
