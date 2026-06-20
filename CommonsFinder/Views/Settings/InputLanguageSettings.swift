//
//  InputLanguageSettings.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 16.06.26.
//

import SwiftUI

struct InputLanguageSettings: View {

    @AppStorage("additionalInputLanguages") private var additionalInputLanguages: [WikimediaLanguage] = []

    @Environment(WikimediaLanguageStore.self) private var languageStore


    @State private var isShowingAdditionaLanguageSheet = false

    private func onDelete(_ indexSet: IndexSet) {
        additionalInputLanguages.remove(atOffsets: indexSet)
    }

    private func onMove(_ indexSet: IndexSet, offset: Int) {
        additionalInputLanguages.move(fromOffsets: indexSet, toOffset: offset)
    }

    private func addLanguage(_ language: WikimediaLanguage) {
        if alreadyChoosenLanguageCodes.contains(language.code) {
            additionalInputLanguages.removeAll(where: {
                $0.code == language.code
            })
        } else {
            additionalInputLanguages.append(language)
        }
    }

    private var alreadyChoosenLanguageCodes: Set<String> {
        Set(
            languageStore.preferredLanguages.map(\.code) + additionalInputLanguages.map(\.code)
        )
    }


    var body: some View {
        List {
            Section("System Languages") {
                ForEach(Locale.LanguageCode.preferredLanguageCodes) { languageCode in
                    Text(languageCode.localizedLanguageName)
                }
            }

            Section("Additional Languages") {
                ForEach(additionalInputLanguages) { language in
                    Text(language.description)
                }
                .onMove(perform: onMove)
                .onDelete(perform: onDelete)

                addButton
            }
        }
        .toolbar { EditButton() }
        .navigationTitle("Input Languages")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.default, value: additionalInputLanguages)
        .sheet(isPresented: $isShowingAdditionaLanguageSheet) {
            AddLanguageDialog(
                alreadyChoosenLanguageCodes: alreadyChoosenLanguageCodes,
                onLanguageChoosen: addLanguage
            )

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
