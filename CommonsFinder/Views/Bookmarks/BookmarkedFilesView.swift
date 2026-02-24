//
//  BookmarkedFilesView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 17.06.25.
//

import Algorithms
import GRDB
import GRDBQuery
import SwiftUI
import os.log

struct BookmarkedFilesView: View {
    @State private var mediaFileInfos: [MediaFileInfo] = []
    @State private var observationTask: Task<Void, Never>?
    @State private var order: SearchOrder = .newest
    @State private var searchText = ""
    @State private var isSearchPresented = false

    @Environment(\.appDatabase) private var appDatabase

    var body: some View {

        ScrollView(.vertical) {
            if mediaFileInfos.isEmpty, searchText.isEmpty {
                BookmarksUnavailableView()
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
        .navigationTitle("Bookmarks")
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

            let originalIDs: [String]

            do {
                let initialFetchedResults = try appDatabase.fetchBookmardMediaFileInfos(
                    order: order == .newest ? .desc : .asc,
                    searchText: searchText
                )

                originalIDs = initialFetchedResults.map(\.id)
                mediaFileInfos = initialFetchedResults
            } catch {
                logger.error("Failed to fetch reciently viewed media \(error)")
                return
            }

            // NOTE: The observation is mainly to observe for bookmark toggling.
            // IMPORTANT: we want retain the orginal order, and not cause layout shifts if the original order would changes.
            // thats why we fetch by IDs in the observation, not the original request itself!
            observationTask?.cancel()
            observationTask = Task<Void, Never> {
                let observation = ValueObservation.tracking { [originalIDs] db in
                    try MediaFilesByIDRequest(ids: originalIDs).fetch(db)
                }

                do {
                    for try await refreshedMediaFileInfos in observation.values(in: appDatabase.reader) {
                        try Task.checkCancellation()
                        let grouped = refreshedMediaFileInfos.grouped(by: \.id)
                        mediaFileInfos = originalIDs.compactMap { id in
                            grouped[id]?.first
                        }
                    }
                } catch {
                    logger.error("Failed to fetch reciently viewed media \(error)")
                }
            }
        }


    }
}

#Preview {
    BookmarkedFilesView()
}
