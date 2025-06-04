//
//  RecentlyViewedView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 21.05.25.
//

import GRDB
import SwiftUI
import os.log

struct RecentlyViewedView: View {
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
                    let orderedIds = try appDatabase.fetchOrderedMediaFileIDs(order: .desc)

                    let observation = ValueObservation.tracking { db in
                        try MediaFileInfo.fetchAll(ids: orderedIds, db: db)
                    }

                    for try await freshMediaFileInfos in observation.values(in: appDatabase.reader) {
                        try Task.checkCancellation()
                        // NOTE: real-time re-ordering of the list is *not desired* here in this view.
                        // But we still want to get updates to the files (eg. bookmark, etc.),
                        // To achieve that and retaining the original order when this view was opened,
                        // we map the original ids to the results:

                        let groupedResult = Dictionary(grouping: freshMediaFileInfos, by: \.id)
                        mediaFileInfos = orderedIds.compactMap { id in
                            groupedResult[id]?.first
                        }
                    }
                } catch {
                    logger.error("Failed to observe media files \(error)")
                }
            }
        }
    }
}

#Preview {
    RecentlyViewedView()
}
