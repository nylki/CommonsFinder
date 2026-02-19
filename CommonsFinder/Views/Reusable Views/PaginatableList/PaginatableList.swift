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

    @State private var prewarmTasks: [Int: Task<Void, Never>] = [:]

    private func checkPagination(visibleItem: Item) {
        let threshold = min(items.count - 1, max(0, items.count - 5))
        guard threshold > 0 else { return }
        let thresholdItem = items[threshold]

        if visibleItem == thresholdItem {
            paginationRequest()
        }
    }

    private func schedulePrewarmTask(itemIdx: Int, isVisible: Bool) {
        if isVisible, prewarmTasks[itemIdx] == nil {
            prewarmTasks[itemIdx] = Task<Void, Never> {
                do {
                    let nextIdx = itemIdx + 1
                    if (items.count - 1) >= nextIdx {
                        try await Task.sleep(for: .milliseconds(650))
                        canPrewarmItem(items[nextIdx])
                    }
                } catch {}
                prewarmTasks[itemIdx] = nil
            }
        } else {
            prewarmTasks[itemIdx]?.cancel()
            prewarmTasks[itemIdx] = nil
        }
    }

    var body: some View {
        let enumeratedItems = Array(items.enumerated())

        LazyVStack(spacing: 20) {
            ForEach(enumeratedItems, id: \.element.id) { (idx, item) in
                itemView(item)
                    .onScrollVisibilityChange(threshold: 0.1) { isVisible in
                        if isVisible {
                            checkPagination(visibleItem: item)
                        }
                        schedulePrewarmTask(itemIdx: idx, isVisible: isVisible)
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
