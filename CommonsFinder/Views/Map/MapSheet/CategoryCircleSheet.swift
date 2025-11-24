//
//  CategoryCircleSheet.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 18.11.25.
//

import SwiftUI

struct CategoryCircleSheet: View {
    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.locale) private var locale
    @Environment(Navigation.self) private var navigation
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Namespace private var namespace: Namespace.ID

    var model: CategoriesAroundLocationModel
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
