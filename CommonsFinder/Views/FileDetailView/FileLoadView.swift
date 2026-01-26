//
//  FileLoadView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 23.05.25.
//

import CommonsAPI
import SwiftUI
import os.log

struct FileLoadView: View {
    let title: String
    let navigationNamespace: Namespace.ID

    @State private var mediaFileInfo: MediaFileInfo?

    @Environment(\.appDatabase) private var appDatabase

    var body: some View {
        if let mediaFileInfo {
            FileDetailView(mediaFileInfo, namespace: navigationNamespace)
        } else {
            ProgressView().progressViewStyle(.circular)
                .task {
                    do {
                        guard let rawFileMetadata = try await Networking.shared.api.fetchFullFileMetadata(.titles([title])).first else {
                            return
                        }
                        let mediaFile = MediaFile(apiFileMetadata: rawFileMetadata)
                        mediaFileInfo = .init(mediaFile: mediaFile, itemInteraction: nil)
                    } catch {
                        logger.error("Failed to dynamically load media file with just the title \(error)")
                    }
                }
        }

    }
}

//#Preview {
//    FileLoadView()
//}
