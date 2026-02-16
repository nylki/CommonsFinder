//
//  LanguageButtons.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 27.01.26.
//

import SwiftUI

struct LanguageButtons: View {
    let disabledLanguages: [LanguageCode]
    let onSelect: (WikimediaLanguage) -> Void

    var body: some View {
        ForEach(WikimediaLanguage.all) { language in
            Button(language.localizedDescription) {
                onSelect(language)
            }
            .disabled(disabledLanguages.contains(language.code))
        }
    }
}
