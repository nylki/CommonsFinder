//
//  InputLanguageButtons.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 27.01.26.
//

import Algorithms
import SwiftUI

struct InputLanguageButtons: View {
    let disabledLanguages: [Locale.LanguageCode]
    let onSelect: (Locale.LanguageCode) -> Void

    @AppStorage("additionalInputLanguages")
    private var additionalInputLanguages: [Locale.LanguageCode] = []

    private var languages: [Locale.LanguageCode] {
        (Locale.LanguageCode.preferredLanguageCodes + additionalInputLanguages)
            .uniqued(on: \.id)
    }

    init(disabledLanguages: [String], onSelect: @escaping (Locale.LanguageCode) -> Void) {
        self.disabledLanguages = disabledLanguages.map { Locale.LanguageCode($0) }
        self.onSelect = onSelect

    }

    var body: some View {
        ForEach(languages) { language in
            Button(language.localizedLanguageName) {
                onSelect(language)
            }
            .disabled(disabledLanguages.contains(language))
        }
    }
}
