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
    let inititalTags: [TagItem]
    let onEditedTags: ([TagItem]) -> Void

    init(
        initialTags: [TagItem],
        onEditedTags: @escaping ([TagItem]) -> Void
    ) {
        self.inititalTags = initialTags
        self.onEditedTags = onEditedTags
    }

    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDatabase) private var appDatabase

    @State private var viewModel = TagPickerModel()

    var body: some View {
        VStack(spacing: 0) {
            navHeader
                .padding([.horizontal, .top])
                .padding(.bottom, 10)

            Divider()

            ScrollView(.vertical) {
                SearchedView(model: viewModel)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .onChange(of: inititalTags, initial: true) {
            let tagModels: [TagModel] = inititalTags.map(TagModel.init)
            viewModel.tags = .init(tagModels)
        }
        .onChange(of: viewModel.searchText) {
            viewModel.search()
        }
        .task {
            viewModel.appDatabase = appDatabase
        }
    }

    private var navHeader: some View {
        VStack {
            HStack {
                Button("Cancel", action: dismiss.callAsFunction)
                    .frame(width: 75)

                Spacer()

                Text("Categories & Depicted").bold()

                Spacer()

                Button("Accept", action: accept)
                    .frame(width: 75)
            }
            SearchBar(text: $viewModel.searchText)
        }
    }

    private func accept() {
        //        let pickedStatements = viewModel.getPickedStatements()
        onEditedTags(viewModel.pickedTags.map(\.tagItem))
        dismiss()
    }
}

private struct SearchedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @Namespace private var categoryAnimation
    let model: TagPickerModel

    @State private var focusedTag: TagModel?

    var body: some View {
        VStack(alignment: .leading) {
            // TODO: make header sticky
            header.padding()
            ZStack {
                @Bindable var model = model

                HFlowLayout(alignment: .bottomLeading) {
                    ForEach(model.combinedItems) { tag in
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

                    }
                    .buttonStyle(.plain)

                }

            }
            .animation(.default, value: model.combinedItems)
            .padding([.top, .trailing], 5)
            .padding(.leading, 10)

            Spacer()
        }

        .overlay {
            if model.isSearching {
                ZStack {
                    Color.clear.frame(minWidth: 0, maxWidth: .infinity)
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            HStack {
                Text("\(model.pickedCategories.count) categories")
                    .underline(color: .category)
                    .bold()
                    .contentTransition(.numericText(value: Double(model.pickedCategories.count)))


                if model.pickedCategories.count >= 1 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.category)
                        .transition(.scale)
                }
            }

            Spacer(minLength: 0)


            HStack {
                Text("\(model.pickedDepictions.count) depicted concepts")
                    .underline(color: .depict)
                    .bold()
                    .contentTransition(.numericText(value: Double(model.pickedDepictions.count)))

                if model.pickedDepictions.count >= 1 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.depict)
                        .transition(.scale)
                }
            }
        }
        .animation(.bouncy(duration: 1, extraBounce: 0.1), value: model.pickedDepictions.count)
        .animation(.bouncy(duration: 1, extraBounce: 0.1), value: model.pickedCategories.count)

    }
}


#Preview(traits: .previewEnvironment) {
    TagPicker(initialTags: []) { pickedTags in
        print(pickedTags)
    }
}
