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

    @State private var paginationModel: PaginatableCategoryMediaFiles? = nil
    @State private var paginationedLoadedDate: Date?
    @State private var paginationModelNeedsReloadDate: Date?
    @State private var searchOrder: SearchOrder = .relevance
    @State private var deepCategoryEnabled = false
    @State private var searchString = ""
    @State private var isSearchPresented = false

    @State private var subCategories: [CategoryInfo] = []
    @State private var parentCategories: [CategoryInfo] = []
    @State private var selectedMediaTab: MediaTab = .category

    @State private var isSubCategoriesExpanded = false
    @State private var isParentCategoriesExpanded = false
    @State private var hasBeenInitialized = false

    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.locale) private var locale
    @Environment(Navigation.self) private var navigation
    @Environment(MapModel.self) private var mapModel
    @Namespace private var namespace

    private var resolvedCategoryName: String? {
        item?.base.commonsCategory
    }

    private var title: String {
        item?.base.label ?? resolvedCategoryName ?? ""
    }

    private func loadPaginationModel() async {
        do {
            paginationModel = try await .init(
                appDatabase: appDatabase,
                categoryName: resolvedCategoryName,
                depictItemID: item?.base.wikidataId,
                order: searchOrder,
                deepCategorySearch: deepCategoryEnabled,
                searchString: searchString
            )
        } catch {
            logger.error("failed to set pagination model for new search order \(error)")
        }
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading) {
                if !isSearchPresented {
                    header
                    Divider()
                }

                HStack {
                    SearchOrderButton(searchOrder: $searchOrder)
                    Spacer()
                    DeepCategoryToggle(enabled: $deepCategoryEnabled)
                        .disabled(subCategories.isEmpty)
                }
                .padding(.horizontal)

                mediaList

                Spacer()
            }
            .animation(.default, value: isSearchPresented)
        }

        .containerRelativeFrame(.horizontal)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .toolbar(removing: .title)
        .searchable(
            text: $searchString,
            isPresented: $isSearchPresented,
            prompt: "Search in this category"
        )
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
            guard oldValue != newValue else { return }
            guard !hasBeenInitialized, networkInitTask == nil else {
                return
            }

            startInitialNetworkTask()
        }
        .onChange(of: searchString) { oldValue, newValue in
            guard newValue != oldValue else { return }
            paginationModelNeedsReloadDate = .now
        }
        .onChange(of: searchOrder) { oldValue, newValue in
            guard newValue != oldValue else { return }
            paginationModelNeedsReloadDate = .now
        }
        .onChange(of: deepCategoryEnabled) { oldValue, newValue in
            guard newValue != oldValue else { return }
            paginationModelNeedsReloadDate = .now
        }
        .task(id: paginationModelNeedsReloadDate) {
            guard let paginationModelNeedsReloadDate else { return }
            let lastRefresh = (paginationedLoadedDate ?? Date.distantPast).distance(to: paginationModelNeedsReloadDate)
            guard lastRefresh > 0 else { return }
            paginationModel = nil
            try? await Task.sleep(for: .milliseconds(500))
            paginationedLoadedDate = paginationModelNeedsReloadDate
            await loadPaginationModel()
        }
    }

    @ViewBuilder
    private var mediaList: some View {
        ZStack {
            if let paginationModel, !paginationModel.isEmpty {
                PaginatableMediaList(
                    items: paginationModel.mediaFileInfos,
                    status: paginationModel.status,
                    paginationRequest: paginationModel.paginate
                )
            } else if paginationModel?.isEmpty == true {
                mediaUnavailableView
                    .padding()
            } else {
                Color.clear.frame(height: 500)
                    .overlay(alignment: .top) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .padding()
                    }
            }
        }
        .animation(.snappy, value: paginationModel == nil)
    }
    
    @ViewBuilder
    private var mediaUnavailableView: some View {
        ContentUnavailableView {
            Label("No Images", systemImage: "photo.stack")
        } description: {
            if !searchString.isEmpty {
                if deepCategoryEnabled {
                    Text("No images for \"\(searchString)\" in **\(title)**.")
                } else {
                    Text("No images for \(searchString) in **\(title)**. Try to include subcategories for more results.")
                }
            } else {
                if deepCategoryEnabled {
                    Text("No images depicting **\(title)** and no images found in subcategories of **\(title)**.")
                } else {
                    Text("No images depicting **\(title)** or tagged with the category.")
                }
                
                
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.largeTitle).bold()
            subheadline
            if let item, let coordinate = item.base.coordinate {
                InlineMap(
                    coordinate: coordinate,
                    item: .category(item.base),
                    knownName: title,
                    mapPinStyle: .pinOnly,
                    details: .none
                )
                .padding(.vertical)
            }
            relatedCategoriesView
        }
        .animation(.default, value: item)
        .animation(.default, value: item?.base.coordinate)
        .scenePadding()
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

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
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
                    if item.base.coordinate != nil {
                        Button("Show on Map", systemImage: "map") {
                            navigation.showOnMap(category: item.base, mapModel: mapModel)
                        }
                    }
                    Button("Add Image", systemImage: "plus") {
                        let newDraftOptions = NewDraftOptions(tag: TagItem(item.base, pickedUsages: [.category, .depict]))
                        navigation.openNewDraft(options: newDraftOptions)
                    }

                    CategoryLinkSection(item: item)
                }
            }
            .disabled(item == nil)
        }
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
        .animation(.default, value: subCategories)
        .animation(.default, value: parentCategories)
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

        if item.base.wikidataId != nil && item.base.commonsCategory != nil {
            paginationModelNeedsReloadDate = .now
        }

        networkInitTask?.cancel()
        networkInitTask = Task<Void, Never> {
            #if DEBUG
                var debugLabel = item.base.label ?? item.base.commonsCategory ?? ""
                logger.info("CAT: start network task for Category \"\(debugLabel)\".")
            #endif
            do {
                if let wikidataID = item.base.wikidataId {

                    let result = try await DataAccess.fetchCategoriesFromAPI(
                        wikidataIDs: [wikidataID],
                        shouldCache: true,
                        appDatabase: appDatabase
                    )

                    if let fetchedCategory = result.fetchedCategories.first {
                        if let commonsCategory = fetchedCategory.commonsCategory {
                            try await resolveCategoryDetails(category: commonsCategory)
                        }
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

                if self.item?.base.commonsCategory != refreshedItem.base.commonsCategory || self.item?.base.wikidataId != refreshedItem.base.wikidataId {
                    paginationModelNeedsReloadDate = .now
                }
                if self.item != refreshedItem {
                    self.item = refreshedItem
                }


                startDatabaseTask(incrementViewCount: false)
            }

            print("refreshed item \(refreshedItem.debugDescription)")
        } catch {
            logger.error("Failed to fetch category freshly from network")
        }

        if paginationModel == nil, paginationModelNeedsReloadDate == nil {
            paginationModelNeedsReloadDate = .now
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
