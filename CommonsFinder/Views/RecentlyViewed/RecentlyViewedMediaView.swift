//
//  RecentlyViewedMediaView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 21.05.25.
//

import GRDB
import SwiftUI
import os.log

struct RecentlyViewedMediaView: View {
    @State private var mediaFileInfos: [MediaFileInfo]?
    @State private var observationTask: Task<Void, Never>?

    @Environment(\.appDatabase) private var appDatabase

    var body: some View {
        ScrollView(.vertical) {
            if let mediaFileInfos {
                if mediaFileInfos.isEmpty {
                    ContentUnavailableView(
                        "No recently viewed images",
                        image: "photo.stack",
                        description: Text("You will find a history of your previously viewed images here.")
                    )
                } else {
                    LazyVStack(spacing: 20) {
                        ForEach(mediaFileInfos) { mediaFileInfo in
                            MediaFileListItem(mediaFileInfo: mediaFileInfo)
                        }
                    }
                    .compositingGroup()
                    .scenePadding()
                    .safeAreaPadding(.trailing)
                    .shadow(color: .black.opacity(0.15), radius: 10)
                }
            }
        }
        .navigationTitle("Recently Viewed")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard observationTask == nil else { return }

            observationTask?.cancel()
            observationTask = Task<Void, Never> {
                do {
                    mediaFileInfos = try appDatabase.fetchRecentlyViewedMediaFileInfos(order: .desc)
                } catch {
                    logger.error("Failed to observe media files \(error)")
                }
            }
        }
    }
}

#Preview {
    RecentlyViewedMediaView()
}
