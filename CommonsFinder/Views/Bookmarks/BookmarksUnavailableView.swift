//
//  BookmarksUnavailableView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 23.06.25.
//

import SwiftUI

struct BookmarksUnavailableView: View {
    var body: some View {
        ContentUnavailableView(
            "No bookmarks",
            systemImage: "bookmark.slash"
        )
    }
}

#Preview {
    BookmarksUnavailableView()
}
