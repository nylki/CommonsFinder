//
//  CategoryCircleSheet.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 18.11.25.
//

import CoreLocation
import SwiftUI

struct CategoryCircleSheet: View {
    var model: CategoriesAroundLocationModel
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
    @Previewable @State var model: CategoriesAroundLocationModel?


    Color.clear
        .sheet(isPresented: .constant(true)) {
            if let model {
                CategoryCircleSheet(model: model, mapAnimationNamespace: namespace, onClose: {})
            }

        }
        .task {
            model = .init(appDatabase: appDatabase, coordinate: .init(latitude: 0, longitude: 0), radius: 250, categoryItems: [.earth, .randomItem(id: "12345")])
        }
}
