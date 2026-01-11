//
//  FilenameErrorSheet.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 02.01.26.
//

import SwiftUI
import TipKit

struct FilenameErrorSheet: View {
    let name: String
    let filenameType: FileNameType
    let validationResult: NameValidationResult

    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            if filenameType == .custom {
                TipView(FilenameTip(), arrowEdge: .top) { action in
                    openURL(.commonsWikiFileNaming)
                }
            }
        }

    }
}

//#Preview {
//    FilenameErrorSheet()
//}
