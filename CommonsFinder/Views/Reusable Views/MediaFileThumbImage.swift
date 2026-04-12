//
//  MediaFileThumbImage.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 09.02.26.
//

import Nuke
import NukeUI
import SwiftUI
import os.log

struct MediaFileThumbImage: View {
    private let request: ImageRequest?
    private let name: String
    private let isImageLoadingAllowed: Bool

    init(_ mediaFileInfo: MediaFileInfo, isImageLoadingAllowed: Bool = true) {
        self.name = mediaFileInfo.mediaFile.name
        self.isImageLoadingAllowed = isImageLoadingAllowed
        self.request = mediaFileInfo.thumbRequest
    }


    var body: some View {
        ZStack {
            if let request, ImagePipeline.shared.cache.containsCachedImage(for: request) || isImageLoadingAllowed {
                LazyImage(
                    request: request,
                    transaction: .init(animation: .linear)
                ) { state in
                    stateView(state)
                }
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .transition(.opacity)
            }
        }
        .animation(.linear, value: isImageLoadingAllowed)
    }

    @ViewBuilder
    private func stateView(_ state: LazyImageState) -> some View {
        if let image = state.image {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .transition(.opacity)
        } else if let error = state.error, (error as? ImagePipeline.Error)?.description != ImagePipeline.Error.imageRequestMissing.description {

            Image(systemName: "photo.badge.exclamationmark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding()
                .transition(.opacity)
        } else {
            ProgressView()
                .progressViewStyle(.circular)
                .transition(.opacity)
        }
    }
}

#Preview {
    MediaFileThumbImage(.makeRandomUploaded(id: "1", .horizontalImage))
        .frame(width: 200, height: 200)
        .clipped()

}
