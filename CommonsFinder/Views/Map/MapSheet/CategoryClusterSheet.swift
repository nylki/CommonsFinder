//
//  CategoryClusterSheet.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 04.03.25.
//

import SwiftUI
import os.log

struct CategoryClusterSheet: View {

    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.locale) private var locale
    @Environment(Navigation.self) private var navigation
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Namespace private var namespace: Namespace.ID

    var model: CategoriesInClusterModel
    let mapAnimationNamespace: Namespace.ID
    let onClose: () -> Void

    private var currentItemTitle: Text? {
        return nil
    }

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
