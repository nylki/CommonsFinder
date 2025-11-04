//
//  VerticalMediaList.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 04.11.25.
//

import SwiftUI

struct VerticalMediaList: View {
    let model: ClusterModel
    @Namespace private var namespace

    @State private var isInitialScrollFinished = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 20) {
                    if let mediaPaginationModel = model.mediaPaginationModel {

                        let mediaFileInfos = mediaPaginationModel.mediaFileInfos

                        ForEach(mediaPaginationModel.mediaFileInfos) { mediaFileInfo in
                            let isSelected = mediaFileInfo.id == model.mapSheetFocusedClusterItem.viewID(type: String.self)

                            MediaFileListItem(mediaFileInfo: mediaFileInfo)
                                .id(mediaFileInfo.id)

                                .modifier(MediaFileContextMenu(mediaFileInfo: mediaFileInfo, namespace: namespace))
                                .animation(.default, value: isSelected)

                                .onScrollVisibilityChange { visible in
                                    guard isInitialScrollFinished else { return }

                                    /// FIXME: only change when initial scroll finished!
                                    if visible {
                                        model.mapSheetFocusedClusterItem = .init(id: mediaFileInfo.id)
                                    }
                                    guard visible, mediaPaginationModel.status != .idle(reachedEnd: true), mediaPaginationModel.status != .isPaginating else { return }
                                    let threshold = min(mediaFileInfos.count - 1, max(0, mediaFileInfos.count - 1))
                                    guard threshold > 0 else { return }
                                    let thresholdItem = mediaFileInfos[threshold]

                                    if mediaFileInfo == thresholdItem {
                                        mediaPaginationModel.paginate()
                                    }
                                }
                        }


                        if mediaPaginationModel.status == .isPaginating {
                            ProgressView()
                                .frame(width: 100).progressViewStyle(.circular)
                        }
                    } else {
                        ProgressView()
                            .frame(width: 100).progressViewStyle(.circular)
                    }
                }
                .safeAreaPadding(.bottom, 500)
                .shadow(color: .black.opacity(0.125), radius: 10, y: 7)
                .shadow(color: .black.opacity(0.075), radius: 100, y: 7)
                .padding(.horizontal)
                .scrollTargetLayout()
                .opacity(isInitialScrollFinished ? 1 : 0)
                .task {
                    try? await Task.sleep(for: .milliseconds(200))
                    let id: String = model.mapSheetFocusedClusterItem.viewID(type: String.self) ?? ""
                    proxy.scrollTo(id, anchor: .center)
                    isInitialScrollFinished = true
                }
            }
        }


        //        .scrollPosition($model.mapSheetFocusedClusterItem, anchor: .top)
        .containerRelativeFrame(.horizontal)

    }
}

#Preview {
    VerticalMediaList(model: try! .init(cluster: .init(h3Index: 1, mediaItems: [], categoryItems: [])))
}
