//
//  WikiCategoryView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 12.03.25.
//


import CommonsAPI
import FrameUp
import SwiftUI
import os.log

enum WikiCategoryType: Equatable {
    case wikiItemID(String)
    case categoryName(String)
}
private enum MediaTab {
    case category
    case depections
}

struct WikiCategoryView: View {
    let config: WikiCategoryType

    init(config: WikiCategoryType) {
        self.config = config
    }

    init(tag: TagItem) {
        switch tag.baseItem {
        case .wikidataItem(let wikidataItem):
            self.config = .wikiItemID(wikidataItem.id)
        case .category(let category):
            self.config = .categoryName(category)
        }
    }

    @State private var initTask: Task<Void, Never>?

    @State private var wikidataItem: WikidataItem?

    @State private var paginationModel: PaginatableWikiCategoryFiles? = nil

    @State private var subCategories: [String] = []
    @State private var parentCategories: [String] = []
    @State private var selectedMediaTab: MediaTab = .category
    @State private var isSubCategoriesExpanded = false
    @State private var isParentCategoriesExpanded = false
    @State private var showTitleInToolbar = false

    @State private var hasBeenInitialized = false

    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.locale) private var locale

    @Namespace private var namespace

    private var resolvedCategoryName: String? {
        if let category = wikidataItem?.commonsCategory {
            category
        } else if case .categoryName(let category) = config {
            category
        } else {
            nil
        }
    }

    //    private var url: URL {
    //        URL(string: "https://commons.wikimedia.org/wiki/Category:\(resolvedCategoryName)")!
    //    }

    var body: some View {
        let title = wikidataItem?.label ?? resolvedCategoryName ?? ""

        ScrollView(.vertical) {
            VStack(alignment: .leading) {

                VStack(alignment: .leading) {
                    Text(title)
                        .font(.largeTitle).bold()
                        .opacity(showTitleInToolbar ? 0 : 1)
                        .onScrollVisibilityChange(threshold: 0.01) { visible in
                            withAnimation {
                                showTitleInToolbar = !visible
                            }
                        }
                    if let description = wikidataItem?.description {
                        Text(description)
                    }

                    relatedCategoriesView
                }
                .animation(.default, value: wikidataItem)
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
            .onChange(of: config, initial: true) {
                if !hasBeenInitialized {
                    loadData()
                }
            }
        }
        .animation(.default, value: paginationModel == nil)
        .navigationTitle(title)
        .toolbar(removing: .title)
        .toolbar {
            // NOTE: ^ having navigationTitle but removing it from display
            // and instead showing the following, allows us to have a two-line
            // title, but still retain the title in the nav-stack (when long-pressing back-buttons, eg.)
            // or potentially for screen-readers or other stuff.
            ToolbarItem(placement: .principal) {
                if showTitleInToolbar {
                    Text(title)
                        .font(.headline)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 3)
                        .allowsTightening(true)
                }
            }

            ToolbarItem(placement: .automatic) {

                Menu("More", systemImage: "ellipsis.circle") {
                    WikiCategoryLinkSection(
                        wikidataItem: wikidataItem,
                        categoryName: resolvedCategoryName
                    )
                }

            }
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
    }

    private func loadData() {
        hasBeenInitialized = false
        initTask?.cancel()
        initTask = Task<Void, Never> {
            do {
                switch config {
                case .wikiItemID(let id):
                    if let item = try await CommonsAPI.API.shared
                        .findCategoriesForWikidataItems([id], languageCode: locale.wikiLanguageCodeIdentifier)
                        .first
                    {
                        wikidataItem = .init(apiItem: item)

                        if let category = wikidataItem?.commonsCategory {
                            try await resolveCategoryDetails(category: category)
                        }
                    }


                    paginationModel = try await .init(appDatabase: appDatabase, categoryName: wikidataItem?.commonsCategory, depictItemID: id)

                case .categoryName(let category):
                    async let categoryTask: () = resolveCategoryDetails(category: category)
                    async let itemsTask = CommonsAPI.API.shared.findWikidataItemsForCategories(
                        [category],
                        languageCode: locale.wikiLanguageCodeIdentifier
                    )
                    let (_, items) = try await (categoryTask, itemsTask)

                    if let item = items.first {
                        self.wikidataItem = .init(apiItem: item)
                    }

                    paginationModel = try await .init(appDatabase: appDatabase, categoryName: category, depictItemID: wikidataItem?.id)

                }

                // Expand sub-categories if there are no images to show
                if paginationModel?.isEmpty == true {
                    isParentCategoriesExpanded = true
                    isSubCategoriesExpanded = true

                }

            } catch is CancellationError {
                // NOTE: os.log crashes previews in XCode 16
                // if string is not interpolated. sigh.
                logger.debug("\("load data cancelled in WikiCategoryView")")
            } catch {
                logger.error("Failed to resolve wikidata item \(error)")
            }

            hasBeenInitialized = true
        }
    }

    struct RelatedCategoriesInfo {
        let subCategories: [String]
        let parentCategories: [String]
    }


    private func resolveCategoryDetails(category: String) async throws {
        let relatedCategories = try await CommonsAPI.API.shared.fetchCategoryInfo(of: category)
        if let relatedCategories {
            subCategories = relatedCategories.subCategories
            parentCategories = relatedCategories.parentCategories
        }
    }
}


#Preview(traits: .previewEnvironment) {
    WikiCategoryView(config: .categoryName("Earth"))
}
#Preview("Different Category String", traits: .previewEnvironment) {
    WikiCategoryView(config: .categoryName("Lise-Meitner-Haus"))
}

#Preview("No images", traits: .previewEnvironment) {
    WikiCategoryView(config: .categoryName("Squares in Berlin"))
}
