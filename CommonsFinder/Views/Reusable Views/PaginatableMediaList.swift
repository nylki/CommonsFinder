//
//  CategoryMediaList.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 13.03.25.
//

import SwiftUI

// NOTE: This view is used in Search and Category
struct PaginatableMediaList: View {
    let items: [MediaFileInfo]
    let status: PaginatableMediaFiles.Status

    // when a search bar is visible
    @Environment(\.isSearching) private var isSearching: Bool

    // TODO: can we get rid of this and inject the toolbar as content from outside instead maybe?
    var toolOverlayPadding = false

    let paginationRequest: () -> Void


    var body: some View {
        ScrollView(.vertical) {

            LazyVStack(spacing: 20) {
                ForEach(items) { mediaFileInfo in
                    MediaFileListItem(mediaFileInfo: mediaFileInfo)
                        .onScrollVisibilityChange { visible in
                            guard visible else { return }
                            let threshold = min(items.count - 1, max(0, items.count - 5))
                            guard threshold > 0 else { return }
                            let thresholdItem = items[threshold]

                            if mediaFileInfo == thresholdItem {
                                paginationRequest()
                            }
                        }
                }

                paginatingIndicator
            }
            .compositingGroup()
            .scenePadding()
            .padding(.top, toolOverlayPadding ? 40 : 0)
            .shadow(color: .black.opacity(0.15), radius: 10)
            .animation(.default, value: items)
        }
        .scrollIndicators(.visible, axes: .vertical)
        .onChange(of: status, initial: true) {
            if status == .idle(reachedEnd: false), items.isEmpty {
                paginationRequest()
            }
        }
    }

    @ViewBuilder
    private var paginatingIndicator: some View {
        Color.clear.frame(height: 400)
            .overlay(alignment: .top) {
                switch status {
                case .unknown:
                    EmptyView()
                case .isPaginating:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .padding(.vertical)
                case .error:
                    Text("There was an error paginating more results.")
                case .idle(let reachedEnd):
                    if reachedEnd {
                        Text("You reached the end of \(items.count) files!")
                    }
                }
            }
    }
}

#Preview(traits: .previewEnvironment) {
    PaginatableMediaList(
        items: [
            .makeRandomUploaded(id: "1", .horizontalImage),
            .makeRandomUploaded(id: "2", .verticalImage),
            .makeRandomUploaded(id: "3", .squareImage),
        ],
        status: .idle(reachedEnd: false),
        paginationRequest: {}
    )
}
