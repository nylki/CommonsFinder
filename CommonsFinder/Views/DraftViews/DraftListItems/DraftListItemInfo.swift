//
//  DraftListItemInfo.swift
//  CommonsFinder
//
//  Created by Tom on 16.07.26.
//

import SwiftUI

struct DraftListItemInfo: View {
    let name: String
    let statusLine: AttributedString?
    let combinedFileSizeInByte: Int64?
    let count: Int

    var body: some View {
        VStack(alignment: .leading) {
            if !name.isEmpty {
                Text(name)
                    .lineLimit(2, reservesSpace: false)
                    .foregroundStyle(.primary)
                    .bold()
            } else {
                Text("untitled Draft")
                    .italic()
                    .foregroundStyle(.secondary)
            }

            if let statusLine {
                Text(statusLine)
            } else if let combinedFileSizeInByte {
                let byteStyle = ByteCountFormatStyle(style: .file, allowedUnits: [.kb, .mb, .gb, .tb])
                let totalBytesFormatted = byteStyle.format(combinedFileSizeInByte)

                Text(
                    "\(count) files · \(totalBytesFormatted)",
                    comment: "file count · total combined file size (formatted)"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.leading)
        .padding(.horizontal, 5)
    }
}

#Preview {
    DraftListItemInfo(name: "Build in City XY", statusLine: nil, combinedFileSizeInByte: 9_999_999, count: 2)
}
