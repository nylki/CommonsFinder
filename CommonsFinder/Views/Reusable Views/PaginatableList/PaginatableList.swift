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
    let paginationRequest: () -> Void

    let canPrewarmItem: (_ item: Item) -> Void

    /// return the item to render and if the item or one of its neighbors (prev, next) was visible long enough (based on scroll visibility)
    @ViewBuilder
    let itemView: (_ item: Item, _ itemOrNeighorVisible: Bool) -> ItemView

    @State private var visibilityTask: [Item.ID: Task<Void, Never>] = [:]
    @State private var longViewedItems: Set<Item.ID> = .init()

    private func checkPagination(visibleItem: Item) {
        let threshold = min(items.count - 1, max(0, items.count - 5))
        guard threshold > 0 else { return }
        let thresholdItem = items[threshold]

        if visibleItem == thresholdItem {
            paginationRequest()
        }
    }

    private func itemOrNeighborVisible(item: Item) -> Bool {
        if longViewedItems.contains(item.id) {
            return true
        }
        guard let idx = items.lastIndex(of: item) else {
            return false
        }

        if let prevID = items[safeIndex: idx - 1]?.id, longViewedItems.contains(prevID) {
            return true
        }
        if let nextID = items[safeIndex: idx + 1]?.id, longViewedItems.contains(nextID) {
            return true
        }

        return false
    }

    private func scheduleVisibilityTask(id: Item.ID, prewarmItem: Item, isVisible: Bool) {
        if isVisible, visibilityTask[id] == nil {
            visibilityTask[id] = Task<Void, Never> {
                do {
                    try await Task.sleep(for: .milliseconds(650))
                    longViewedItems.insert(id)
                    canPrewarmItem(prewarmItem)
                } catch {

                }
                visibilityTask[id] = nil
            }
        } else {
            visibilityTask[id]?.cancel()
            visibilityTask[id] = nil
        }
    }

    var body: some View {
        let enumeratedItems = Array(items.enumerated())

        LazyVStack(spacing: 20) {
            ForEach(enumeratedItems, id: \.element.id) { (idx, item) in
                itemView(item, itemOrNeighborVisible(item: item))
                    .onScrollVisibilityChange(threshold: 0.1) { isVisible in
                        if isVisible {
                            checkPagination(visibleItem: item)
                        }
                        if let nextItem = enumeratedItems[safeIndex: idx + 1]?.element {
                            scheduleVisibilityTask(id: item.id, prewarmItem: nextItem, isVisible: isVisible)
                        }
                    }
            }

            paginatingIndicator
        }
        .compositingGroup()
        .padding()
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

#Preview(traits: .previewEnvironment) {
    ScrollView(.vertical) {
        PaginatableList(
            items: [
                Category.earth, Category.testItemNoDesc, Category.earthExtraLongLabel, Category.testItemNoDesc,
            ],
            status: .unknown,
            paginationRequest: {
                print("paginate")
            },
            canPrewarmItem: { item in }
        ) { item, _ in
            CategoryTeaser(categoryInfo: .init(item))
                .frame(height: 185)
        }
    }
}
