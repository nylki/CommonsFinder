//
//  RelatedCategoriesView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 26.02.26.
//

import GRDB
import SwiftUI
import os.log

struct RelatedCategoriesView: View {
    let item: CategoryInfo
    let initialType: RelatedCategoriesType

    @State private var subCategoryPagination: PaginatableCategorySearch?
    @State private var parentCategoryPagination: PaginatableParentCategories?

    @State private var subOrder: SearchOrder = .relevance
    @State private var parentOrder: CategoryMembersSort = .ascending

    @State private var isLoading = true
    @State private var error: Error?
    @State private var selectedType: RelatedCategoriesType?
    @Environment(\.appDatabase) private var appDatabase

    private var selectedPaginationModel: PaginatableCategories? {
        switch selectedType {
        case .parent: parentCategoryPagination
        case .sub: subCategoryPagination
        case .none: nil
        }
    }

    private var type: String {
        (selectedType ?? initialType).description
    }

    var body: some View {
        ScrollView(.vertical) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .padding()
            } else if let error {
                ContentUnavailableView {
                    Label("Error Loading Categories", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error.localizedDescription)
                }
            } else if let selectedPaginationModel {
                PaginatableCategoryList(
                    items: selectedPaginationModel.categoryInfos,
                    status: selectedPaginationModel.status,
                    paginationRequest: selectedPaginationModel.paginate
                )
                .containerShape(.rect(cornerRadius: 32))
                .compositingGroup()
                .scenePadding()
                .shadow(color: .black.opacity(0.15), radius: 10)
            } else {
                ContentUnavailableView("No Categories found", systemImage: "folder")
            }

            Color.clear.frame(minWidth: 0, maxWidth: .infinity)

            Spacer()
        }
        .animation(.default, value: isLoading)
        .animation(.default, value: selectedPaginationModel == nil)
        .navigationTitle("\(type) (\(item.base.commonsCategory ?? item.id))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .task {
            if selectedType == nil {
                selectedType = initialType
            }
        }
        .task(id: parentOrder.rawValue + subOrder.rawValue + (selectedType?.rawValue ?? "")) {
            guard selectedType != nil else { return }
            await loadData()
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {

        ToolbarItem(placement: .title) {
            Menu {
                if let commonsCategory = item.base.commonsCategory {
                    Section {
                        Text(commonsCategory)
                    }
                }
                ForEach(RelatedCategoriesType.allCases) { type in
                    Button(action: { selectedType = type }) {
                        Label {
                            Text(type.description)
                        } icon: {
                            if selectedType == type {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                }
            } label: {
                HStack {
                    // NOTE: Label doesn't work here (icon is always leading, even with custom label style
                    Text(type)
                        .bold()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
            }
        }

        if #available(iOS 26.0, *) {
            if let commonsCategory = item.base.commonsCategory {
                ToolbarItem(placement: .subtitle) {
                    Text(commonsCategory)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }

        switch selectedType {
        case .parent:
            ToolbarItem(placement: .topBarTrailing) {
                SearchOrderButton(
                    searchOrder: $parentOrder,
                    possibleCases: [.ascending, .descending]
                )
            }
        case .sub, .none:
            ToolbarItem(placement: .topBarTrailing) {
                SearchOrderButton(
                    searchOrder: $subOrder,
                    possibleCases: [.relevance, .newest, .oldest]
                )
            }
        }
    }

    private func loadData() async {
        if selectedType == nil {
            selectedType = initialType
        }
        guard parentCategoryPagination == nil || subCategoryPagination == nil else { return }

        try? await Task.sleep(for: .milliseconds(50))
        guard !Task.isCancelled else { return }

        isLoading = true
        error = nil
        do {
            switch selectedType {
            case .parent:
                guard let commonsCategory = item.base.commonsCategory else {
                    throw RelatedCategoriesError.missingCategoryName
                }
                parentCategoryPagination = nil
                parentCategoryPagination = try await PaginatableParentCategories(
                    appDatabase: appDatabase,
                    categoryName: commonsCategory,
                    sort: parentOrder
                )

            case .sub:
                guard let commonsCategory = item.base.commonsCategory else {
                    throw RelatedCategoriesError.missingCategoryName
                }
                subCategoryPagination = nil
                subCategoryPagination = try await PaginatableCategorySearch(
                    appDatabase: appDatabase,
                    searchString: "",
                    inParentCategory: commonsCategory,
                    sort: subOrder,
                    searchTargets: .commons
                )
            case .none:
                assertionFailure()
            }
        } catch {
            self.error = error
            logger.error("Failed to load related categories: \(error)")
        }
        isLoading = false
    }
}

enum RelatedCategoriesError: Error, LocalizedError {
    case missingCategoryName

    var errorDescription: String? {
        switch self {
        case .missingCategoryName:
            return "Category name is missing"
        }
    }
}

#Preview(traits: .previewEnvironment) {
    NavigationView {
        RelatedCategoriesView(item: CategoryInfo.randomItem(id: "1"), initialType: .sub)
    }
}
