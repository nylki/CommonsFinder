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
    @State private var paginationedLoadedDate: Date?
    @State private var paginationModelNeedsReloadDate: Date?
    @State private var searchOrder: SearchOrder = .relevance
    @State private var deepCategoryEnabled = false
    @State private var searchString = ""
    @State private var isSearchPresented = false

    @Namespace private var namespace

    @State private var isOptionsBarSticky = false
    @State private var scrollState: ScrollState = .init()

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
    private var resolvedCategoryName: String? {
        item?.base.commonsCategory ?? initialItem.base.commonsCategory
    }

    private var title: String {
        initialItem.base.label ?? initialItem.base.label ?? resolvedCategoryName ?? ""
    }

    private var coordinate: CLLocationCoordinate2D? {
        item?.base.coordinate ?? initialItem.base.coordinate
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
        let dragGesture = DragGesture(minimumDistance: 25, coordinateSpace: .local)
            .onChanged { v in
                let newDirection: ScrollState.Direction =
                    if v.predictedEndLocation.y > v.startLocation.y {
                        .up
                    } else if v.predictedEndLocation.y < v.startLocation.y {
                        .down
                    } else {
                        .none
                    }

                guard newDirection != scrollState.lastDirection else { return }
                scrollState.lastDirection = newDirection
            }

        ScrollView(.vertical) {
            VStack(alignment: .leading) {
                header

                optionsBar
                    .opacity(isOptionsBarSticky ? 0 : 1)
                    .allowsHitTesting(!isOptionsBarSticky)
                    .onScrollVisibilityChange(threshold: 0.1) { visible in
                        isOptionsBarSticky = !visible
                    }

                mediaList

                Spacer()
            }
            .animation(.default, value: isSearchPresented)
        }
        .onScrollPhaseChange { oldPhase, newPhase, context in
            guard oldPhase != newPhase else { return }
            scrollState.phase = newPhase
        }
        .overlay(alignment: .top) {
            let stickyOptionsBarVisible =
                isOptionsBarSticky && paginationModel != nil && paginationModel?.isEmpty != true && scrollState.lastDirection == .up && scrollState.phase == .idle

            if stickyOptionsBarVisible {
                optionsBar
            }
        }
        .animation(.linear(duration: 0.25), value: scrollState)
        .containerRelativeFrame(.horizontal)
        .simultaneousGesture(dragGesture, isEnabled: isOptionsBarSticky)
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
    private var optionsBar: some View {
        HStack {
            SearchOrderButton(searchOrder: $searchOrder)
            DeepCategoryToggle(enabled: $deepCategoryEnabled)
                .disabled(subCategories.isEmpty)
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
        .padding(.horizontal)
    }

    @ViewBuilder
    private var mediaList: some View {
        VStack {
            if let paginationModel, !paginationModel.isEmpty {
                PaginatableMediaList(
                    items: paginationModel.mediaFileInfos,
                    status: paginationModel.status,
                    paginationRequest: paginationModel.paginate
                )
                .transition(.opacity)
            } else if paginationModel?.isEmpty == true {
                mediaUnavailableView
                    .padding()
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .padding()
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .animation(.snappy, value: paginationModel == nil)
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
                relatedCategoriesView
            }

        }
        .animation(.default, value: item)
        .animation(.default, value: item?.base.coordinate)
        .scenePadding()
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

                    CategoryLinkSection(item: item)
                }
            }
            .disabled(item == nil)
        }
    }

    @ViewBuilder private var relatedCategoriesView: some View {

        VStack(alignment: .leading) {
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
                            try await resolveCategoryDetails(category: commonsCategory)
                        }
                    }
                } else if let commonsCategory = initialItem.base.commonsCategory {

                    async let categoryTask: () = resolveCategoryDetails(category: commonsCategory)
                    async let itemsTask = Networking.shared.api.findWikidataItemsForCategories(
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

    struct RelatedCategoriesInfo {
        let subCategories: [String]
        let parentCategories: [String]
    }


    private func resolveCategoryDetails(category: String) async throws {
        let relatedCategories = try await Networking.shared.api.fetchCategoryInfo(of: category)
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
