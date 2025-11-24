//
//  MediaClusterSheet.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 07.11.25.
//

import SwiftUI
import os.log

struct MediaClusterSheet: View {
    @Namespace private var namespace: Namespace.ID
    @Environment(\.locale) private var locale
    @Environment(Navigation.self) private var navigation
    @Environment(MediaFileReactiveCache.self) private var mediaFileCache

    let model: MediaInClusterModel
    let mapAnimationNamespace: Namespace.ID
    let onClose: () -> Void

    @State private var selectedDetent: PresentationDetent = .height(270)

    private var currentItemTitle: Text? {
        if let selectedImage = model.mediaPaginationModel?.mediaFileInfos.first(where: { $0.id == model.focusedItemID }) {
            Text(selectedImage.mediaFile.bestShortTitle)
        } else {
            nil
        }
    }

    private let topSafeArea = 70.0

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    if let paginationModel = model.mediaPaginationModel {
                        HorizontalMediaMapList(
                            focusedItem: $model.mapSheetFocusedItem,
                            paginationModel: paginationModel,
                            mapAnimationNamespace: mapAnimationNamespace
                        )
                    }

                    if let currentItemTitle {
                        currentItemTitle
                            .padding()
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                }
                //NOTE: the regular top safe area is ignore (below), because it appears to be too large
                // instead a better fitted one is used here. May need to adjust or re-test in future versions or different
                // detents and configs.
                .padding(.top, topSafeArea)
            }
            .ignoresSafeArea(.container, edges: .top)
            .toolbar {
                MapSheetToolbar(model: model, onClose: onClose)
            }

        }
        .presentationDetents([.height(270), .medium])
        .task {
            await model.observeAndResolveMediaItems()
        }
    }
}
