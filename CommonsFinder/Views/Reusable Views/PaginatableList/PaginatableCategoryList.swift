//
//  PaginatableCategoryList.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 01.09.25.
//

import SwiftUI

struct PaginatableCategoryList: View {
    let items: [CategoryInfo]
    let status: PaginationStatus
    let paginationRequest: () -> Void

    var body: some View {
        PaginatableList(
            items: items,
            status: status,
            paginationRequest: paginationRequest,
            canPrewarmItem: { item in }
        ) { item, _ in
            CategoryTeaser(categoryInfo: item)
                .frame(height: 185)
        }
    }
}

#Preview(traits: .previewEnvironment) {
    @Previewable @State var items = ["0", "1", "2", "3", "4", "5", "6"].map { CategoryInfo.randomItem(id: $0) }
    ScrollView(.vertical) {
        PaginatableCategoryList(
            items: items,
            status: .idle(reachedEnd: false),
            paginationRequest: {
                items.append(contentsOf: [UUID().uuidString, UUID().uuidString].map { CategoryInfo.randomItem(id: $0) })
            }
        )
        .containerShape(.rect(cornerRadius: 32))
    }
}
