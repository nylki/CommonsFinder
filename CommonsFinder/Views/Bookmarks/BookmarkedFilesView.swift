//
//  BookmarkedFilesView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 17.06.25.
//

import GRDBQuery
import SwiftUI
import os.log

struct BookmarkedFilesView: View {
    @Query(AllBookmarksFileRequest()) private var mediaFileInfos

    var body: some View {
        if mediaFileInfos.isEmpty {
            BookmarksUnavailableView()
        } else {
            ScrollView(.vertical) {
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
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
        }

    }
}

#Preview {
    BookmarkedFilesView()
}
