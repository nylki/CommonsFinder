//
//  CategoryClusterSheet.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 04.03.25.
//

import SwiftUI
import os.log

struct CategoryClusterSheet: View {
    var model: CategoriesInClusterModel
    let mapAnimationNamespace: Namespace.ID
    let onClose: () -> Void

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            HorizontalCategoryMapList(
                focusedItem: $model.mapSheetFocusedItem,
                categories: model.resolvedCategories,
                mapAnimationNamespace: mapAnimationNamespace
            )
            .toolbar {
                MapSheetToolbar(model: model, onClose: onClose)
            }
        }
        .presentationDetents([.height(250)])
        .task(id: model.categories) {
            await model.observeAndResolveCategories()
        }
    }
}

#Preview(traits: .previewEnvironment) {
    @Previewable @Environment(\.appDatabase) var appDatabase
    @Previewable @Namespace var namespace
    @Previewable @State var model: CategoriesInClusterModel?


    Color.clear
        .sheet(isPresented: .constant(true)) {
            if let model {
                CategoryClusterSheet(model: model, mapAnimationNamespace: namespace, onClose: {})
            }

        }
        .task {
            model = try? .init(appDatabase: appDatabase, cluster: .init(h3Index: 123445, mediaItems: [], categoryItems: [.earthExtraLongLabel, .earth, .testItemNoLabel]))
        }
}
