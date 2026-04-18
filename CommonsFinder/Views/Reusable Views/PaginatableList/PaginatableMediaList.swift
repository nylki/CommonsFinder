//
//  CategoryMediaList.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 13.03.25.
//

import Nuke
import SwiftUI

struct PaginatableMediaList: View {
    let items: [MediaFileInfo]
    let status: PaginationStatus
    let paginationRequest: () -> Void

    private let imagePrefetcher = ImagePrefetcher()

    private func prewarmItem(_ item: MediaFileInfo) {
        if let imageRequest = item.thumbRequest {
            imagePrefetcher.startPrefetching(with: [imageRequest])
        }
    }

    var body: some View {
        PaginatableList(
            items: items,
            status: status,
            paginationRequest: paginationRequest,
            canPrewarmItem: prewarmItem
        ) { item, itemOrNeighborVisible in
            let isImageLoadingAllowed = itemOrNeighborVisible || items.first == item

            MediaFileListItem(
                mediaFileInfo: item,
                isImageLoadingAllowed: isImageLoadingAllowed
            )
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
