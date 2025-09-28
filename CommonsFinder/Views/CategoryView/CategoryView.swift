//
//  CategoryView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 12.03.25.
//


import CommonsAPI
import FrameUp
import GRDB
import SwiftUI
import os.log

private enum MediaTab {
    case category
    case depictions
}

struct CategoryView: View {
    private let initialItem: CategoryInfo

    init(_ item: CategoryInfo) {
        self.initialItem = item
    }

    @State private var networkInitTask: Task<Void, Never>?
    @State private var databaseTask: Task<Void, Never>?

    @State private var item: CategoryInfo?

    @State private var paginationModel: PaginatableCategoryFiles? = nil

    @State private var subCategories: [CategoryInfo] = []
    @State private var parentCategories: [CategoryInfo] = []
    @State private var selectedMediaTab: MediaTab = .category
    @State private var isSubCategoriesExpanded = false
    @State private var isParentCategoriesExpanded = false
    @State private var showTitleInToolbar = false

    @State private var hasBeenInitialized = false

    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.locale) private var locale

    @Namespace private var namespace

    private var resolvedCategoryName: String? {
        item?.base.commonsCategory
    }

    private var title: String {
        item?.base.label ?? resolvedCategoryName ?? ""
    }


    @ViewBuilder
    private var subheadline: some View {

        let description = item?.base.description
        let shouldShowCategory = (resolvedCategoryName != title) && !title.isEmpty

        if shouldShowCategory, let resolvedCategoryName {
            VStack(alignment: .leading) {
                Text(resolvedCategoryName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()

                if let description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                }
            }


        } else if let description, !description.isEmpty {
            Text(description)
                .font(.subheadline)
        }
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading) {
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.largeTitle).bold()
                    subheadline
                    if let coordinate = item?.base.coordinate {
                        InlineMap(
                            coordinate: coordinate,
                            knownName: title,
                            mapPinStyle: .pinOnly,
                            details: .none
                        )
                        .padding(.vertical)
                    }
                    relatedCategoriesView
                }
                .animation(.default, value: item)
                .scenePadding()

                Divider()

                if let paginationModel {
                    if !paginationModel.isEmpty {
                        PaginatableMediaList(
                            items: paginationModel.mediaFileInfos,
                            status: paginationModel.status,
                            paginationRequest: paginationModel.paginate
                        )
                    } else {
                        ContentUnavailableView {
                            Label("No Images", systemImage: "photo.stack")
                        } description: {
                            Text("No images depicting *\(title)* or tagged with the category.")
                        }
                        .padding()
                    }
                }

                Spacer()
            }
            .onAppear {
                if databaseTask == nil {
                    startDatabaseTask(incrementViewCount: true)
                }
            }
            .onDisappear {
                databaseTask?.cancel()
                databaseTask = nil
            }
            .onChange(of: item) { oldValue, newValue in
                guard !hasBeenInitialized, networkInitTask == nil else {
                    return
                }

                startInitialNetworkTask()
            }
        }
        .containerRelativeFrame(.horizontal)
        .animation(.default, value: paginationModel == nil)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            //            ToolbarItem(placement: .principal) {
            //                if showTitleInToolbar {
            //                    Text(title)
            //                        .font(.headline)
            //                        .lineLimit(2)
            //                        .fixedSize(horizontal: false, vertical: true)
            //                        .padding(.vertical, 3)
            //                        .allowsTightening(true)
            //                }
            //            }

            ToolbarItem(placement: .automatic) {
                let isBookmarked = (item ?? initialItem).isBookmarked
                Button(
                    isBookmarked ? "Remove Bookmark" : "Add Bookmark",
                    systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
                ) {
                    updateBookmark(!isBookmarked)
                }
            }
            ToolbarItem(placement: .automatic) {
                Menu("More", systemImage: "ellipsis") {
                    if let item {
                        CategoryLinkSection(item: item)
                    }
                }
                .disabled(item == nil)
            }
        }
        .toolbar(removing: .title)
    }

    @ViewBuilder private var relatedCategoriesView: some View {

        VStack(alignment: .leading) {
            if !parentCategories.isEmpty || !subCategories.isEmpty {
                DisclosureGroup(
                    "\(parentCategories.count) Parent Categories",
                    isExpanded: $isParentCategoriesExpanded
                ) {
                    RelatedCategoryView(categories: parentCategories)
                }
                .disabled(parentCategories.isEmpty)


                DisclosureGroup(
                    "\(subCategories.count) Subcategories",
                    isExpanded: $isSubCategoriesExpanded
                ) {
                    RelatedCategoryView(categories: subCategories)
                }
                .disabled(subCategories.isEmpty)
            }
        }
    }

    private func startDatabaseTask(incrementViewCount: Bool) {
        databaseTask?.cancel()
        databaseTask = Task<Void, Never> {

            do {
                let updatedItem = try appDatabase.updateLastViewed(item ?? initialItem, incrementViewCount: incrementViewCount)

                guard let existingID = updatedItem.base.id else {
                    assertionFailure("We expect the item to be persisted after calling appDatabase.updateLastViewed")
                    return
                }

                let observation = ValueObservation.tracking { db in
                    try Category
                        //  required, because we update `lastViewed` above.
                        .including(optional: Category.itemInteraction)
                        .filter(id: existingID)
                        .asRequest(of: CategoryInfo.self)
                        .fetchOne(db)
                }
                for try await updatedCategoryInfo in observation.values(in: appDatabase.reader) {
                    try Task.checkCancellation()

                    #if DEBUG
                        let debugLabel = updatedCategoryInfo?.base.label ?? updatedCategoryInfo?.base.commonsCategory ?? ""
                        logger.info("CAT: Category \"\(debugLabel)\" has been updated.")
                        logger.debug("CAT: Category viewCount: \(updatedCategoryInfo?.itemInteraction?.viewCount ?? 0)")
                    #endif

                    item = updatedCategoryInfo
                }
            } catch {
                logger.error("CAT: Failed to observe CategoryInfo changes \(error)")
            }
        }
    }
    /// initializes pagination for `item` and resolves sub+parent categories as well as refreshes the wikidata base item.
    private func startInitialNetworkTask() {
        // TODO: we can opimistically init the pagination from the given Category
        // since we don't expect the basic info of wikidataID and commonsCategory
        // to change often.

        hasBeenInitialized = false
        guard let item else { return }
        networkInitTask?.cancel()
        networkInitTask = Task<Void, Never> {
            #if DEBUG
                var debugLabel = item.base.label ?? item.base.commonsCategory ?? ""
                logger.info("CAT: start network task for Category \"\(debugLabel)\".")
            #endif
            do {
                if let wikidataID = item.base.wikidataId {
                    if let apiItem = try await CommonsAPI.API.shared
                        .findCategoriesForWikidataItems([wikidataID], languageCode: locale.wikiLanguageCodeIdentifier)
                        .first
                    {
                        let fetchedCategory = Category(apiItem: apiItem)

                        try appDatabase.upsert(fetchedCategory)

                        if let commonsCategory = fetchedCategory.commonsCategory {
                            try await resolveCategoryDetails(category: commonsCategory)
                        }

                        paginationModel = try await .init(
                            appDatabase: appDatabase,
                            categoryName: fetchedCategory.commonsCategory,
                            depictItemID: wikidataID
                        )
                    }
                } else if let commonsCategory = initialItem.base.commonsCategory {

                    async let categoryTask: () = resolveCategoryDetails(category: commonsCategory)
                    async let itemsTask = CommonsAPI.API.shared.findWikidataItemsForCategories(
                        [commonsCategory],
                        languageCode: locale.wikiLanguageCodeIdentifier
                    )
                    let (_, apiItems) = try await (categoryTask, itemsTask)

                    if let apiItem = apiItems.first {
                        let fetchedCategory = Category(apiItem: apiItem)
                        try appDatabase.upsert(fetchedCategory)
                    }

                    paginationModel = try await .init(
                        appDatabase: appDatabase,
                        categoryName: commonsCategory,
                        depictItemID: item.base.wikidataId
                    )
                }

                // Expand sub-categories if there are no images to show
                if paginationModel?.isEmpty == true {
                    isParentCategoriesExpanded = true
                    isSubCategoriesExpanded = true

                }

            } catch is CancellationError {
                // NOTE: os.log crashes previews in XCode 16
                // if string is not interpolated. sigh.
                logger.debug("CAT: \("load data cancelled in CategoryView")")
            } catch {
                logger.error("CAT:  Failed to resolve wikidata item \(error)")
            }
            #if DEBUG
                debugLabel = item.base.label ?? item.base.commonsCategory ?? ""
                logger.info("CAT: network task for Category \"\(debugLabel)\" finished!")
            #endif

            await refreshFromNetwork()

            hasBeenInitialized = true
        }
    }

    private func refreshFromNetwork() async {
        guard let item else { return }

        do {
            let refreshedItem = try await DataAccess.refreshCategoryInfoFromAPI(categoryInfo: item, appDatabase: appDatabase)

            if let refreshedItem {
                if refreshedItem.base.id != item.base.id {
                    logger.debug("CategoryView: item has a one DB-ID! this edge-case can caused due to redirects.")
                }
                if refreshedItem.base.wikidataId != item.base.wikidataId {
                    logger.debug("CategoryView: Refresh got a redirected item!")
                }
                // TODO: inform the user somehow that the item was merged into another if one if those above ^ happened?

                databaseTask?.cancel()
                self.item = refreshedItem
                startDatabaseTask(incrementViewCount: false)
            }

            print("refreshed item \(refreshedItem.debugDescription)")
        } catch {
            logger.error("Failed to fetch category freshly from network")
        }
    }

    private func updateBookmark(_ value: Bool) {
        guard let item else { return }
        do {
            self.item = try appDatabase.updateBookmark(item, bookmark: value)
        } catch {
            logger.error("Failed to update bookmark on wiki item \(item.id): \(error)")
        }
    }

    struct RelatedCategoriesInfo {
        let subCategories: [String]
        let parentCategories: [String]
    }


    private func resolveCategoryDetails(category: String) async throws {
        let relatedCategories = try await CommonsAPI.API.shared.fetchCategoryInfo(of: category)
        // FIXME: cross-resolve against database / and or fetch wikidata items if possible
        if let relatedCategories {
            subCategories = relatedCategories.subCategories.map({ categoryName in
                CategoryInfo(.init(commonsCategory: categoryName))
            })
            parentCategories = relatedCategories.parentCategories.map({ categoryName in
                CategoryInfo(.init(commonsCategory: categoryName))
            })
        }
    }
}


#Preview(traits: .previewEnvironment) {
    NavigationView {
        CategoryView(.init(.init(commonsCategory: "Earth")))
    }
}
#Preview("Different Category String", traits: .previewEnvironment) {
    CategoryView(.init(.init(commonsCategory: "Lise-Meitner-Haus")))
}

#Preview("No images", traits: .previewEnvironment) {
    CategoryView(.init(.init(commonsCategory: "Squares in Berlin")))
}
