//
//  InputLanguageSettings.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 16.06.26.
//

import SwiftUI

struct InputLanguageSettings: View {

    @AppStorage("additionalInputLanguages") private var additionalInputLanguages: [Locale.LanguageCode] = []

    @State private var isShowingAdditionaLanguageSheet = false

    private func onDelete(_ indexSet: IndexSet) {
        additionalInputLanguages.remove(atOffsets: indexSet)
    }

    private func onMove(_ indexSet: IndexSet, offset: Int) {
        additionalInputLanguages.move(fromOffsets: indexSet, toOffset: offset)
    }

    private func addLanguage(_ languageCode: Locale.LanguageCode) {
        additionalInputLanguages.append(languageCode)
    }

    var body: some View {
        let alreadyChoosenLanguags = Set(Locale.LanguageCode.preferredLanguageCodes + additionalInputLanguages)

        List {
            Section("System Languages") {
                ForEach(Locale.LanguageCode.preferredLanguageCodes) { languageCode in
                    Text(languageCode.localizedLanguageName)
                }
            }

            if !additionalInputLanguages.isEmpty {
                Section("Additional Languages") {
                    ForEach(additionalInputLanguages) { languageCode in
                        Text(languageCode.localizedLanguageName)
                    }
                    .onMove(perform: onMove)
                    .onDelete(perform: onDelete)

                    addButton
                }
            } else {
                addButton
            }


        }
        .toolbar { EditButton() }
        .navigationTitle("Input Languages")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.default, value: additionalInputLanguages)
        .sheet(isPresented: $isShowingAdditionaLanguageSheet) {
            AddLanguageDialog(alreadyChoosenLanguages: alreadyChoosenLanguags, onLanguageChoosen: addLanguage)

        }
    }

    private var addButton: some View {
        Button("Add Language...") {
            isShowingAdditionaLanguageSheet = true
        }
    }
}

#Preview {
    @Previewable var testingLanguages: [Locale.LanguageCode] = [.english, .hawaiian, .cantonese, .māori, .init("fr"), .init("en")]
    @Previewable @State var isShowingList = false

    NavigationStack {
        InputLanguageSettings()
            .onAppear {
                UserDefaults.standard.additionalInputLanguages = [.english, .cantonese, .tibetan, .init("en")]
                isShowingList = true
            }
    }

}


extension Locale.LanguageCode: @retroactive RawRepresentable {
    public var rawValue: String { self.identifier }

    public init?(rawValue: String) {
        self = .init(stringLiteral: rawValue)
    }
}
