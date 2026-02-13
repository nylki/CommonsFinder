//
//  PaginatableList.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 01.09.25.
//

import SwiftUI

struct PaginatableList<Item: Equatable & Identifiable, ItemView: View>: View {
    let items: [Item]
    let status: PaginationStatus
    var toolOverlayPadding = false
    let paginationRequest: () -> Void

    let canPrewarmItem: (_ item: Item) -> Void
    let itemView: (_ item: Item) -> ItemView

    var body: some View {
        let enumeratedItems = Array(items.enumerated())
        LazyVStack(spacing: 20) {
            ForEach(enumeratedItems, id: \.element.id) { (idx, item) in
                itemView(item)
                    .task {
                        do {
                            try await Task.sleep(for: .seconds(1))
                            let nextIdx = idx + 1
                            if (enumeratedItems.count - 1) >= nextIdx {
                                canPrewarmItem(enumeratedItems[nextIdx].element)
                            }
                        } catch {

                        }
                    }
                    .onScrollVisibilityChange { visible in
                        guard visible else { return }
                        let threshold = min(items.count - 1, max(0, items.count - 5))
                        guard threshold > 0 else { return }
                        let thresholdItem = items[threshold]

                        if item == thresholdItem {
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

#Preview {
    PaginatableList(
        items: [
            Category.earth, Category.testItemNoDesc,
        ],
        status: .unknown,
        paginationRequest: {
            print("paginate")
        },
        canPrewarmItem: { item in }
    ) {
        CategoryTeaser(categoryInfo: .init($0))
            .frame(height: 185)
    }
}
