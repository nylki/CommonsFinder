//
//  InputLanguageButtons.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 27.01.26.
//

import Algorithms
import SwiftUI

struct InputLanguageButtons: View {
    @Environment(WikimediaLanguageStore.self) private var languageStore

    let disabledLanguages: [String]
    let onSelect: (WikimediaLanguage) -> Void

    @AppStorage("additionalInputLanguages")
    private var additionalInputLanguages: [WikimediaLanguage] = []

    private var languages: [WikimediaLanguage] {
        (languageStore.preferredLanguages + additionalInputLanguages)
            .uniqued(on: \.id)
    }


    var body: some View {
        ForEach(languages) { language in
            Button(language.name ?? language.autonym ?? language.code) {
                onSelect(language)
            }
            .disabled(disabledLanguages.contains(language.code))
        }
    }
}
