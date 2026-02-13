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

    @State private var wasInViewLongEnough: Bool = false

    init(mediaFileImage: MediaFileInfo) {
        self.request = mediaFileImage.thumbRequest
    }

    var shouldRenderImage: Bool {
        if let request {
            ImagePipeline.shared.cache.containsCachedImage(for: request) || wasInViewLongEnough
        } else {
            false
        }
    }

    var body: some View {
        ZStack {
            if let request, shouldRenderImage {
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
        .animation(.linear, value: shouldRenderImage)
        .task {
            do {
                // This prevents excessive image loads when scrolling rapidly
                try await Task.sleep(for: .milliseconds(250))
                wasInViewLongEnough = true
            } catch {
                //                logger.debug("Cancelled wasInViewLongEnough")
            }
        }
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
    MediaFileThumbImage(mediaFileImage: MediaFileInfo.makeRandomUploaded(id: "1", .horizontalImage))
        .frame(width: 200, height: 200)
        .clipped()

}
