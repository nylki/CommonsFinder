//
//  FileGroupBoxStyle.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.09.25.
//

import SwiftUI

struct FileGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            configuration.label.bold()
            configuration.content
        }
        .padding(.vertical, 5)
    }
}
