//
//  RecentlyViewedMediaView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 21.05.25.
//

import Algorithms
import GRDB
import SwiftUI
import os.log

struct RecentlyViewedMediaView: View {
    @State private var mediaFileInfos: [MediaFileInfo] = []
    @State private var observationTask: Task<Void, Never>?
    @State private var order: SearchOrder = .newest
    @State private var searchText = ""
    @State private var isSearchPresented = false

    @Environment(\.appDatabase) private var appDatabase

    var body: some View {
        ScrollView(.vertical) {
            if mediaFileInfos.isEmpty, searchText.isEmpty {
                ContentUnavailableView(
                    "No recently viewed images",
                    systemImage: "photo.stack",
                    description: Text("You will find a history of your previously viewed images here.")
                )
            } else if mediaFileInfos.isEmpty, !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
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
        .navigationTitle("Recently Viewed")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, isPresented: $isSearchPresented)
        .searchPresentationToolbarBehavior(.avoidHidingContent)
        .toolbar {
            ToolbarItem {
                SearchOrderButton(searchOrder: $order, possibleCases: [.newest, .oldest])
            }
            ToolbarItem {
                Button("Search", systemImage: "magnifyingglass") {
                    isSearchPresented = true
                }
            }
        }
        .onChange(of: (searchText + order.rawValue), initial: true) { oldValue, newValue in
            guard observationTask == nil || (newValue != oldValue) else {
                return
            }
            logger.debug("observation change: \(newValue) !=? \(oldValue)")

            observationTask?.cancel()
            observationTask = Task<Void, Never> {
                let observation = ValueObservation.tracking { [order, searchText] db in
                    try AllRecentlyViewedMediaFileRequest(
                        order: order == .newest ? .desc : .asc,
                        searchText: searchText
                    )
                    .fetch(db)
                }

                var orginalOrderedIDs: [MediaFileInfo.ID] = []

                do {
                    for try await refreshedMediaFileInfos in observation.values(in: appDatabase.reader) {
                        try Task.checkCancellation()
                        // IMPORTANT: we want retain the orginal order, to not cause annoying
                        // layout changes when the user taps on an item and returns here.
                        if orginalOrderedIDs.isEmpty {
                            orginalOrderedIDs = refreshedMediaFileInfos.map(\.id)
                        }

                        var refreshedGrouped = refreshedMediaFileInfos.grouped(by: \.id)

                        mediaFileInfos = orginalOrderedIDs.compactMap { id in
                            if let match = refreshedGrouped[id]?.first {
                                refreshedGrouped.removeValue(forKey: id)
                                return match
                            } else {
                                return nil
                            }
                        }

                        let umatchedRefreshed = refreshedGrouped.values
                        assert(umatchedRefreshed.isEmpty)
                    }
                } catch {

                }
            }
        }
    }

}

#Preview(traits: .previewEnvironment) {
    Color.clear.fullScreenCover(isPresented: .constant(true)) {
        NavigationStack {
            RecentlyViewedMediaView()
        }
    }
}
