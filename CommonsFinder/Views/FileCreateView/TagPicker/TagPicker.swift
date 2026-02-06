//
//  TagPicker.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 24.11.24.
//

import CommonsAPI
import FrameUp
import OrderedCollections
import SwiftUI
import os.log

/// For now this one only is intended to be used for P180 depict statements
struct TagPicker: View {
    let initialTags: [TagItem]
    let suggestedCategories: [Category]

    let isLoadingSuggestedTags: Bool
    let onEditedTags: ([TagItem]) -> Void

    @Environment(\.locale) private var locale
    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.dismiss) private var dismiss
    @Namespace private var namespace

    @State private var isSearchPresented = false
    @State private var isSearching = false
    @State private var focusedTag: TagModel?
    @State private var searchText = ""

    var searchTextBinding: Binding<String> {
        .init(
            get: {
                searchText
            },
            set: { newValue in
                guard newValue != searchText else { return }
                searchText = newValue
                search()
            })
    }

    @State private var isSuggestedNearbyTagsExpanded = false

    @ObservationIgnored
    @State private var searchTask: Task<Void, Never>?

    @State private var tags: OrderedSet<TagModel> = []
    @State private var searchedTags: OrderedSet<TagModel> = []
    @State private var suggestedTags: OrderedSet<TagModel> = []

    var pickedTags: [TagModel] {
        tags.filter { $0.pickedUsages.isEmpty == false }
    }
    var pickedCategories: [TagModel] {
        tags.filter { $0.pickedUsages.contains(.category) }
    }
    var pickedDepictions: [TagModel] {
        tags.filter { $0.pickedUsages.contains(.depict) }
    }
    var unPickedTags: [TagModel] {
        tags.filter { $0.pickedUsages.isEmpty }
    }


    private var hasUserMadeChanges: Bool {
        let initial: Set<TagItem> = Set(initialTags)
        let picked: Set<TagItem> = Set(pickedTags.map(\.tagItem))
        return initial != picked
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView(.vertical) {
                    VStack(alignment: .leading) {
                        if !isSearchPresented, !isSuggestedNearbyTagsExpanded {
                            HFlowLayout(alignment: .bottomLeading) {
                                ForEach(tags) { tag in
                                    tagButton(tag)
                                }
                            }
                        }

                        if isSearchPresented {
                            searchedSection

                        } else if isSuggestedNearbyTagsExpanded {
                            suggestionsSection
                        }

                        if isSearching {
                            ZStack {
                                Color.clear.frame(minWidth: 0, maxWidth: .infinity)
                                ProgressView()
                                    .progressViewStyle(.circular)
                            }
                            .padding(.vertical, 50)
                        }

                        Color.clear.frame(minWidth: 0, maxWidth: .infinity)

                        Spacer()
                    }
                    .animation(.default, value: tags)
                    .padding([.top, .trailing], 5)
                    .padding(.leading, 10)
                    .animation(.default, value: searchedTags)
                    .animation(.default, value: suggestedTags)
                    .animation(.default, value: isSuggestedNearbyTagsExpanded)
                    .animation(.default, value: isSearchPresented)

                }
                .searchable(text: searchTextBinding, isPresented: $isSearchPresented, prompt: "Search all categories, locations and items")
                .searchPresentationToolbarBehavior(.avoidHidingContent)
                .scrollDismissesKeyboard(.immediately)
                .onChange(of: focusedTag) { oldValue, newValue in
                    copySuggestedTags()
                }


            }
            .navigationTitle("Categories & Depicted")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: dismiss.callAsFunction) {
                        Label("Cancel", systemImage: "xmark")
                    }
                }
                if hasUserMadeChanges {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(role: .fallbackConfirm, action: accept) {
                            Label("Accept", systemImage: "checkmark")
                        }
                    }
                }


                if !isSuggestedNearbyTagsExpanded {
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Nearby Locations", systemImage: "mappin.and.ellipse") {
                            searchText = ""
                            isSearchPresented = false
                            isSuggestedNearbyTagsExpanded = true
                        }
                    }
                }


            }
            .animation(.default, value: isSuggestedNearbyTagsExpanded)
            .animation(.default, value: hasUserMadeChanges)
            .modifier(
                SafeAreaBarFallback(edge: .top) {
                    NavHeader(
                        namespace: namespace,
                        categoryCount: pickedCategories.count,
                        depictCount: pickedDepictions.count,
                        hasUserMadeChanges: hasUserMadeChanges,
                        onShowPickedResults: {
                            isSearchPresented = false
                            searchText = ""
                        },
                        onAccept: accept
                    )
                    .frame(minWidth: 0, maxWidth: .infinity)


                })
        }
        .interactiveDismissDisabled(hasUserMadeChanges)
        .task {
            if initialTags.isEmpty {
                isSuggestedNearbyTagsExpanded = true
            }

            tags = .init(initialTags.map { TagModel.init(tagItem: $0) })
            suggestedTags = .init(suggestedCategories.map { TagModel.init(tagItem: .init($0)) })
        }
        .onChange(of: isSuggestedNearbyTagsExpanded) {
            if isSuggestedNearbyTagsExpanded == false {
                copySuggestedTags()
            }
        }
    }

    @ViewBuilder
    private var searchedSection: some View {
        let pickedIDs = Set(tags.map(\.id))

        if !searchedTags.isEmpty {
            VStack(alignment: .leading) {

                Text("Search Results for \"\(searchText)\"")
                    .bold()
                    .padding(.vertical)
                HFlowLayout(alignment: .bottomLeading) {
                    ForEach(searchedTags) { tag in
                        tagButton(tag)
                    }
                }
                .animation(.default, value: searchedTags)

                Color.clear.frame(minWidth: 0, maxWidth: .infinity)
            }

            .safeAreaInset(edge: .top) {
                Divider()
            }
            .padding(.top)
        }
    }

    @ViewBuilder
    private var suggestionsSection: some View {
        let pickedIDs = Set(tags.map(\.id))
        let suggestedIDs = Set(suggestedTags.map(\.id))
        let unpickedSuggestedTags = suggestedTags.filter {
            !pickedIDs.contains($0.id)
        }
        let pickedSuggestedTags = pickedTags.filter {
            suggestedIDs.contains($0.id)
        }

        VStack(alignment: .leading, spacing: 20) {

            HStack {
                VStack(alignment: .leading) {
                    Text("Nearby Locations")
                        .font(.title3)
                        .bold()
                    Text("Suggested tags based on the camera location")
                        .font(.callout)
                }

                Spacer()

                if isSuggestedNearbyTagsExpanded {
                    Button("hide suggestions", systemImage: "xmark") {
                        isSuggestedNearbyTagsExpanded = false
                    }
                    .labelStyle(.iconOnly)
                    .buttonBorderShape(.circle)
                    .glassButtonStyle()
                }
            }
            if isLoadingSuggestedTags {
                ProgressView().progressViewStyle(.circular)
            } else if suggestedTags.isEmpty {
                ContentUnavailableView("No nearby locations found", systemImage: "tag.slash")
            } else {
                HFlowLayout(alignment: .bottomLeading) {
                    ForEach(pickedSuggestedTags) { tag in
                        tagButton(tag)
                    }
                    ForEach(unpickedSuggestedTags) { tag in
                        tagButton(tag)
                    }
                }
            }


            Color.clear.frame(minWidth: 0, maxWidth: .infinity)
        }
        .padding()
        .background(Material.thin, in: .rect(cornerRadius: 8))
        .animation(.default, value: isSuggestedNearbyTagsExpanded)
        .padding(.top, 25)


    }

    @ViewBuilder
    private func tagButton(_ tag: TagModel) -> some View {
        TagButton(tag: tag) { focused in
            if focused {
                focusedTag = tag
            } else {
                focusedTag = nil
            }
        }
        .animation(.default) {
            let shouldBlur = focusedTag != nil && focusedTag != tag
            $0
                .opacity(shouldBlur ? 0.5 : 1)
                .blur(radius: shouldBlur ? 5 : 0)
        }
        .buttonStyle(.plain)
    }


    private func accept() {
        onEditedTags(pickedTags.map(\.tagItem))
        dismiss()
    }

    private func search() {
        tags.removeAll(where: \.pickedUsages.isEmpty)
        searchedTags.removeAll()

        copySuggestedTags()

        guard !searchText.isEmpty else { return }

        isSearching = true
        defer { isSearching = false }

        searchTask?.cancel()
        searchTask = Task<Void, Never> {
            do {
                try await Task.sleep(for: .milliseconds(300))
                logger.debug("preferred languages: \(Locale.preferredLanguages)")
                let searchedCategories = try await APIUtils.searchCategories(for: searchText, appDatabase: appDatabase)

                let existingTagIDs = Set(tags.map(\.id))

                let filteredSearchedTags: [TagModel] =
                    searchedCategories.map {
                        TagModel(tagItem: .init($0))
                    }
                    .filter { searchTag in
                        !existingTagIDs.contains(searchTag.id)
                    }

                searchedTags.append(contentsOf: filteredSearchedTags)

            } catch is CancellationError {
                // retry XCode 16.2: Apparently preview crashes when using Logger()?
                //                logger.debug("category search cancelled (debounced)")
            } catch {
                logger.error("wikidata item (tags) search error \(error)")
            }
        }
    }

    func copySuggestedTags() {
        let pickedTags = (suggestedTags.union(searchedTags))
            .filter {
                $0.pickedUsages.isEmpty == false
            }

        if !pickedTags.isEmpty {
            tags.append(contentsOf: pickedTags)
        }
    }
}

struct SafeAreaBarFallback<C: View>: ViewModifier {
    var edge: VerticalEdge

    @ViewBuilder
    var subContent: () -> C

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .safeAreaBar(edge: edge, content: subContent)
        } else {
            content
                .safeAreaInset(edge: edge, content: subContent)
        }
    }
}


private struct NavHeader: View {
    let namespace: Namespace.ID
    let categoryCount: Int
    let depictCount: Int
    let hasUserMadeChanges: Bool
    let onShowPickedResults: () -> Void
    let onAccept: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if #available(iOS 26.0, *) {
            header
                .padding([.horizontal, .top])
                .padding(.bottom, 10)
        } else {
            header
                .padding([.horizontal, .top])
                .padding(.bottom, 10)
                .background(Color(uiColor: .systemBackground))
                .safeAreaInset(edge: .bottom) {
                    Divider()
                }
        }

    }

    private var header: some View {
        HStack {
            Button {
                onShowPickedResults()
            } label: {
                HStack {
                    Text("\(categoryCount) categories")
                        .underline(color: .category)
                        .bold()
                        .contentTransition(.numericText(value: Double(categoryCount)))

                    if categoryCount >= 1 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.category)
                            .transition(.scale)
                    }
                }
            }
            .accentColor(.primary)


            Spacer(minLength: 0)

            Button {
                onShowPickedResults()
            } label: {
                HStack {
                    Text("\(depictCount) depicted concepts")
                        .underline(color: .depict)
                        .bold()
                        .contentTransition(.numericText(value: Double(depictCount)))

                    if depictCount >= 1 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.depict)
                            .transition(.scale)
                    }
                }
            }
            .accentColor(.primary)
        }
        .animation(.default, value: hasUserMadeChanges)
        .animation(.bouncy(duration: 0.6, extraBounce: 0.15), value: categoryCount)
        .animation(.bouncy(duration: 0.6, extraBounce: 0.15), value: depictCount)

    }
}


#Preview(traits: .previewEnvironment) {
    TagPicker(initialTags: [.init(.randomItem(id: "test"), pickedUsages: [.category, .depict])], suggestedCategories: [.earth], isLoadingSuggestedTags: false) { pickedTags in
        print(pickedTags)
    }
}
