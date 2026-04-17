//
//  CategoryView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 12.03.25.
//


import CommonsAPI
import CoreLocation
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
    @State private var subCategoryModel: PaginatableCategorySearch? = nil

    /// NOTE: irregardless of current search parameters we remember if the category initially has images and sub-cats
    /// for better UX when hiding section.
    @State private var hasImages: Bool?
    @State private var hasSubcategories: Bool?

    @State private var paginationedLoadedDate: Date?
    @State private var paginationModelNeedsReloadDate: Date?
    @State private var searchOrder: SearchOrder = .relevance
    @State private var deepCategoryEnabled = false
    @State private var searchString = ""
    @State private var isSearchPresented = false

    @Namespace private var namespace

    @State private var isOptionsBarSticky = false

    @State private var hasInitializedInfo = false
    @State private var hasFinishedRefreshingInfo = false
    @State private var isLoadingPaginationModel = false

    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.locale) private var locale
    @Environment(Navigation.self) private var navigation
    @Environment(MapModel.self) private var mapModel

    private var resolvedCategoryName: String? {
        item?.base.commonsCategory ?? initialItem.base.commonsCategory
    }

    private var title: String {
        initialItem.base.label ?? initialItem.base.label ?? resolvedCategoryName ?? ""
    }

    private var coordinate: CLLocationCoordinate2D? {
        item?.base.coordinate ?? initialItem.base.coordinate
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading) {
                header
                if hasInitializedInfo {
                    if !isSearchPresented {
                        subCategoryList
                    }
                    mediaList
                } else {
                    HStack {
                        Spacer(minLength: 0)
                        ProgressView().progressViewStyle(.circular)
                        Spacer(minLength: 0)
                    }
                }

                Color.clear
                    .frame(height: 1)
                    .frame(minWidth: 0, maxWidth: .infinity)


                Spacer()
            }
            .animation(.default, value: isSearchPresented)
            .animation(.default, value: hasInitializedInfo)
            .animation(.default, value: isLoadingPaginationModel)
        }
        .containerRelativeFrame(.horizontal)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .animation(.default, value: isOptionsBarSticky)
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
            guard !hasFinishedRefreshingInfo, networkInitTask == nil else {
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

            isLoadingPaginationModel = true
            defer { isLoadingPaginationModel = false }

            try? await Task.sleep(for: .milliseconds(500))
            paginationedLoadedDate = paginationModelNeedsReloadDate

            do {
                let newModel = try await PaginatableCategoryMediaFiles(
                    appDatabase: appDatabase,
                    categoryName: resolvedCategoryName,
                    depictItemID: item?.base.wikidataId,
                    order: searchOrder,
                    deepCategorySearch: deepCategoryEnabled,
                    searchString: searchString
                )

                if paginationModel == nil, hasImages == nil {
                    hasImages = newModel.isEmpty == false
                }
                paginationModel = newModel
            } catch {
                logger.error("failed to set pagination model for new search order \(error)")
            }
        }
    }

    @ViewBuilder
    private var optionsBar: some View {
        HStack {
            SearchOrderButton(searchOrder: $searchOrder, possibleCases: [.relevance, .newest, .oldest], showSelectedInLabel: true)
            DeepCategoryToggle(enabled: $deepCategoryEnabled)
                .disabled(subCategoryModel?.isEmpty == true)
            if !isSearchPresented {
                Button {
                    isSearchPresented.toggle()
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .labelStyle(.iconOnly)
                .glassButtonStyle()
            }
            Spacer(minLength: 0)
        }


    }

    @ViewBuilder
    private var subCategoryList: some View {
        VStack {
            if hasSubcategories == true {
                Section {
                    if let subCategoryModel {
                        HorizontalCategoryList(model: subCategoryModel)
                    } else {
                        ProgressView().progressViewStyle(.circular)
                    }
                } header: {
                    HStack {
                        NavigationLink(value: NavigationStackItem.relatedCategories(item ?? initialItem, .sub)) {
                            Label("Subcategories", systemImage: "chevron.right")
                                .labelStyle(SecondaryIconTrailingLabelStyle())
                                .font(.title3)
                        }
                        .tint(.primary)
                        Spacer()
                    }
                    .padding(.leading)
                }
                .transition(.opacity)
                .frame(minWidth: 0, maxWidth: .infinity)
            }
        }
        .animation(.snappy, value: subCategoryModel == nil)
    }

    @ViewBuilder
    private var mediaList: some View {
        let isSubCategorySectionVisible = subCategoryModel?.isEmpty == false

        if hasImages == true {
            // NOTE: only show the image section if the sub-cat section is visible
            // otherwise no need to explicitly label this section.
            if isSubCategorySectionVisible {
                HStack {
                    Text("Images")
                        .labelStyle(SecondaryIconTrailingLabelStyle())
                        .font(.title3)

                    Spacer()
                }
                .padding([.leading, .top])
            }

            optionsBar
                .padding(.leading)
                .onScrollVisibilityChange { visible in
                    isOptionsBarSticky = !visible
                }

            if isLoadingPaginationModel {
                HStack {
                    Spacer(minLength: 0)
                    ProgressView().progressViewStyle(.circular)
                    Spacer(minLength: 0)
                }
                .frame(height: 100)
            } else if let paginationModel {
                PaginatableMediaList(
                    items: paginationModel.mediaFileInfos,
                    status: paginationModel.status,
                    paginationRequest: paginationModel.paginate
                )
                .transition(.opacity)
                .frame(minWidth: 0, maxWidth: .infinity)
            }

            Spacer()

        } else if paginationModel?.isEmpty == true {
            mediaUnavailableView
                .padding()
        } else {
            HStack {
                Spacer(minLength: 0)
                ProgressView()
                    .progressViewStyle(.circular)
                    .padding()
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var mediaUnavailableView: some View {
        ContentUnavailableView {
            Label("No Images", systemImage: "photo.stack")
        } description: {
            if !searchString.isEmpty {
                if deepCategoryEnabled {
                    Text("No images for **\(searchString)** in **\(title)**.", comment: "searchString, title")
                } else {
                    Text("No images for **\(searchString)** in **\(title)**. Try to include subcategories for more results.", comment: "searchString, title")
                }
            } else {
                if deepCategoryEnabled {
                    Text("No images depicting **\(title)** and no images found in subcategories of **\(title)**.", comment: "title, title")
                } else {
                    Text("No images depicting **\(title)** or tagged with the category.", comment: "title, title")
                }


            }
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.largeTitle).bold()

            if !isSearchPresented {
                subheadline

                if let coordinate {
                    InlineMap(
                        coordinate: coordinate,
                        item: .category(item?.base ?? initialItem.base),
                        knownName: title,
                        mapPinStyle: .pinOnly,
                        details: .none
                    )
                    .padding(.vertical)
                }

            }

        }
        .animation(.default, value: item)
        .animation(.default, value: item?.base.coordinate)
        .padding()
    }

    @ViewBuilder
    private var subheadline: some View {

        let description = item?.base.description ?? initialItem.base.description
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

        if isOptionsBarSticky {
            let didUserChangeFilter = deepCategoryEnabled || searchOrder != .relevance

            ToolbarItem(placement: .topBarLeading) {
                Menu("Filter", systemImage: "line.3.horizontal.decrease") {
                    SearchOrderButton(searchOrder: $searchOrder, possibleCases: SearchOrder.allCases)
                        .tint(nil)
                    Button {
                        deepCategoryEnabled.toggle()
                    } label: {
                        Label("Include Subcategories", systemImage: "list.bullet.indent")
                    }
                    .tint(nil)
                    .disabled(subCategoryModel?.isEmpty == true)
                }
                .tint(didUserChangeFilter ? .accent : nil)
            }
        }


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

                    Divider()

                    Menu("New Image", systemImage: "plus") {
                        let tag = TagItem(item.base, pickedUsages: [.category, .depict])
                        Button("from Photos", systemImage: "photo.badge.plus") {
                            navigation.openNewDraft(options: NewDraftOptions(source: .mediaLibrary, tag: tag))
                        }
                        Button("take new Photo", systemImage: "camera") {
                            navigation.openNewDraft(options: NewDraftOptions(source: .camera, tag: tag))
                        }
                        Button("from Files", systemImage: "folder") {
                            navigation.openNewDraft(options: NewDraftOptions(source: .files, tag: tag))
                        }
                    }

                    if item.base.commonsCategory != nil {
                        Section("Related Categories") {
                            NavigationLink(value: NavigationStackItem.relatedCategories(item, .parent)) {
                                Label("Show parent Categories", systemImage: "arrow.up")
                            }
                            NavigationLink(value: NavigationStackItem.relatedCategories(item, .sub)) {
                                Label("Show Subcategories", systemImage: "arrow.down")
                            }
                        }
                    }

                    CategoryLinkSection(item: item)
                }
            }
            .disabled(item == nil)
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
        hasFinishedRefreshingInfo = false
        hasInitializedInfo = false

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

                    let result = try await DataAccess.fetchCombinedCategoriesFromDatabaseOrAPI(
                        wikidataIDs: [wikidataID],
                        // When our item has a wikidata ID we prefer this over a commons category as the source of truth of this category.
                        // so we won't need to provide the category here.
                        commonsCategories: [],
                        forceNetworkRefresh: true,
                        appDatabase: appDatabase
                    )

                    if let fetchedCategory = result.fetchedCategories.first {
                        if let commonsCategory = fetchedCategory.commonsCategory {
                            subCategoryModel = try await PaginatableCategorySearch(
                                appDatabase: appDatabase,
                                searchString: "",
                                inParentCategory: commonsCategory,
                                sort: .relevance,
                                searchTargets: .commons
                            )
                        }
                    }
                } else if let commonsCategory = initialItem.base.commonsCategory {

                    async let categoryTask = try await PaginatableCategorySearch(
                        appDatabase: appDatabase,
                        searchString: "",
                        inParentCategory: commonsCategory,
                        sort: .relevance,
                        searchTargets: .commons
                    )
                    async let itemsTask = Networking.shared.api.findWikidataItemsForCategories(
                        [commonsCategory],
                        languageCode: locale.wikiLanguageCodeIdentifier
                    )
                    let (loadedSubCategoryModel, apiItems) = try await (categoryTask, itemsTask)

                    if let apiItem = apiItems.first {
                        let fetchedCategory = Category(apiItem: apiItem)
                        try appDatabase.upsert(fetchedCategory)
                    }

                    subCategoryModel = loadedSubCategoryModel
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

            hasSubcategories = subCategoryModel?.isEmpty == false
            hasInitializedInfo = true
            await refreshFromNetwork()
            hasFinishedRefreshingInfo = true
        }
    }

    private func refreshFromNetwork() async {
        guard let item else { return }

        do {
            let refreshedItem = try await DataAccess.refreshCategoryInfoFromAPI(categoryInfo: item, appDatabase: appDatabase)

            if let refreshedItem {
                if refreshedItem.id != item.base.id {
                    logger.debug("CategoryView: original item has a different DB-ID (possibly nil)! this edge-case can caused due to redirects.")
                }
                if refreshedItem.wikidataId != item.base.wikidataId {
                    logger.debug("CategoryView: Refresh got a redirected item!")
                }
                // TODO: inform the user somehow that the item was merged into another if one if those above ^ happened?

                databaseTask?.cancel()

                if self.item?.base.commonsCategory != refreshedItem.commonsCategory || self.item?.base.wikidataId != refreshedItem.wikidataId {
                    paginationModelNeedsReloadDate = .now
                }
                if self.item?.base != refreshedItem {
                    self.item?.base = refreshedItem
                }


                startDatabaseTask(incrementViewCount: false)
            }

            logger.debug("refreshed item \(refreshedItem.debugDescription)")
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
}


#Preview("location and sub-cats", traits: .previewEnvironment) {
    NavigationView {
        CategoryView(.init(.init(commonsCategory: "Berlin")))
    }
}
#Preview("no location", traits: .previewEnvironment) {
    NavigationView {
        CategoryView(.init(.init(commonsCategory: "Earth")))
    }
}
#Preview("no sub-cats", traits: .previewEnvironment) {
    NavigationView {
        CategoryView(.init(.init(commonsCategory: "Lise-Meitner-Haus")))
    }
}

#Preview("No images", traits: .previewEnvironment) {
    NavigationView {
        CategoryView(.init(.init(commonsCategory: "Squares in Berlin")))
    }
}
