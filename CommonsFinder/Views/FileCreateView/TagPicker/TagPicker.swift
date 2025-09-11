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

/// For now this one only is intended to be used for P180 depict statements
struct TagPicker: View {
    let initialTags: [TagItem]
    let suggestedNearbyTags: [TagItem]
    let onEditedTags: ([TagItem]) -> Void

    init(
        initialTags: [TagItem],
        suggestedNearbyTags: [TagItem],
        onEditedTags: @escaping ([TagItem]) -> Void
    ) {
        self.initialTags = initialTags
        self.suggestedNearbyTags = suggestedNearbyTags
        self.onEditedTags = onEditedTags
    }

    @Environment(\.locale) private var locale
    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.dismiss) private var dismiss

    @State private var model: TagPickerModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let model {
                WrappedTagPicker(model: model)
            }
        }
        .safeAreaInset(
            edge: .top,
            content: {
                if let model {
                    @Bindable var model = model

                    NavHeader(
                        searchText: $model.searchText,
                        categoryCount: model.pickedCategories.count,
                        depictCount: model.pickedDepictions.count,
                        onAccept: accept
                    )
                    .frame(minWidth: 0, maxWidth: .infinity)
                }
            }
        )
        // FIXME: use safeAreaBar in iOS 26
        .safeAreaInset(
            edge: .bottom,
            content: {
                if let model {
                    let showSuggestedButton = model.searchText.isEmpty && !model.isSuggestedNearbyTagsExpanded
                    ZStack {
                        if showSuggestedButton {
                            HStack {
                                Button {
                                    model.isSuggestedNearbyTagsExpanded.toggle()
                                } label: {
                                    Label("Nearby Tags", systemImage: "mappin.and.ellipse")
                                        .labelStyle(.iconOnly)
                                }
                                .padding()
                                .background(.regularMaterial, in: .circle)

                                Spacer()
                            }
                            .transition(.blurReplace)

                            .padding()

                        }
                    }
                    .animation(.default, value: showSuggestedButton)
                }
            }
        )
        .onAppear {
            guard model == nil else { return }
            model = .init(
                appDatabase: appDatabase,
                initialTags: initialTags,
                suggestedNearbyTags: suggestedNearbyTags
            )
        }
    }

    private func accept() {
        guard let model else { return }
        onEditedTags(model.pickedTags.map(\.tagItem))
        dismiss()
    }
}

private struct NavHeader: View {

    @Binding var searchText: String
    let categoryCount: Int
    let depictCount: Int
    let onAccept: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {

        VStack {
            HStack {
                Button("Cancel", action: dismiss.callAsFunction)
                    .frame(width: 75)

                Spacer()

                Text("Categories & Depicted").bold()

                Spacer()

                Button("Accept", action: onAccept)
                    .frame(width: 75)
            }
            SearchBar(text: $searchText)
            HStack {
                categoryHeader
                Spacer(minLength: 0)
            }
        }
        .padding([.horizontal, .top])
        .padding(.bottom, 10)
        .background(Color(uiColor: .systemBackground))
        .safeAreaInset(edge: .bottom) {
            Divider()
        }
    }

    private var categoryHeader: some View {
        HStack {
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

            Spacer(minLength: 0)

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
        .animation(.bouncy(duration: 0.6, extraBounce: 0.15), value: categoryCount)
        .animation(.bouncy(duration: 0.6, extraBounce: 0.15), value: depictCount)

    }
}


private struct WrappedTagPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @Namespace private var categoryAnimation
    @Bindable var model: TagPickerModel

    @State private var focusedTag: TagModel?

    var body: some View {
        @Bindable var model = model

        ScrollView(.vertical) {
            VStack(alignment: .leading) {

                HFlowLayout(alignment: .bottomLeading) {
                    ForEach(model.tags) { tag in
                        tagButton(tag)
                    }
                }

                if !model.searchText.isEmpty {
                    searchedSection
                } else {
                    suggestionsSection
                }

                if model.isSearching {
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
            .animation(.default, value: model.tags)
            .padding([.top, .trailing], 5)
            .padding(.leading, 10)
            .animation(.default, value: model.searchedTags)
            .animation(.default, value: model.suggestedNearbyTags)
            .animation(.default, value: model.isSuggestedNearbyTagsExpanded)

        }
        .scrollDismissesKeyboard(.immediately)
        .onChange(of: focusedTag) { oldValue, newValue in
            model.copySuggestedTags()
        }
    }

    @ViewBuilder
    private var searchedSection: some View {
        let pickedIDs = Set(model.tags.map(\.id))
        let searchedTagsWithoutPickedOnes = model.searchedTags.filter {
            !pickedIDs.contains($0.id)
        }

        if !searchedTagsWithoutPickedOnes.isEmpty {
            VStack(alignment: .leading) {

                Text("Search Results for \"\(model.searchText)\"")
                    .bold()
                    .padding(.vertical)
                HFlowLayout(alignment: .bottomLeading) {
                    ForEach(searchedTagsWithoutPickedOnes) { tag in
                        tagButton(tag)
                    }
                }
                .animation(.default, value: searchedTagsWithoutPickedOnes)

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
        let pickedIDs = Set(model.tags.map(\.id))
        let suggestedTagsWithoutPickedOnes = model.suggestedNearbyTags.filter {
            !pickedIDs.contains($0.id)
        }

        if model.isSuggestedNearbyTagsExpanded, !suggestedTagsWithoutPickedOnes.isEmpty {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Nearby Tags")
                            .font(.title3)
                            .bold()
                        Text("Suggested tags based on the camera location")
                            .font(.callout)
                    }

                    Spacer()

                    if model.isSuggestedNearbyTagsExpanded {
                        Button("hide suggestions", systemImage: "xmark") {
                            model.isSuggestedNearbyTagsExpanded = false
                        }
                        .labelStyle(.iconOnly)
                        .buttonBorderShape(.circle)
                        .buttonStyle(.glass)
                    }
                }

                HFlowLayout(alignment: .bottomLeading) {
                    ForEach(suggestedTagsWithoutPickedOnes) { tag in
                        tagButton(tag)
                    }
                }

                Color.clear.frame(minWidth: 0, maxWidth: .infinity)
            }
            .padding()
            .background(Material.thin, in: .rect(cornerRadius: 8))
            .animation(.default, value: model.isSuggestedNearbyTagsExpanded)
            .padding(.top, 25)

        }


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
}


#Preview(traits: .previewEnvironment) {
    TagPicker(initialTags: [.init(.randomItem(id: "test"), pickedUsages: [.category, .depict])], suggestedNearbyTags: .sampleTags) { pickedTags in
        print(pickedTags)
    }
}
