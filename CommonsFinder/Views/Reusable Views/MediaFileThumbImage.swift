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
    @State private var wasInViewLongEnough: Bool = false
    @State private var visibilityTask: Task<Void, Never>?

    init(_ mediaFileInfo: MediaFileInfo) {
        self.name = mediaFileInfo.mediaFile.name
        self.request = mediaFileInfo.thumbRequest
    }

    private func startVisibilityTaskIfNeeded() {
        guard request != nil, !wasInViewLongEnough, visibilityTask == nil else { return }
        visibilityTask = Task<Void, Never> {
            // This prevents excessive image loads when scrolling rapidly
            do {
                try await Task.sleep(for: .milliseconds(350))
                wasInViewLongEnough = true
            } catch {}
            visibilityTask = nil
        }
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
        .onScrollVisibilityChange(threshold: 0.1) { isVisible in

            // IMPORTANT: this callback alone is not sufficient for initial scheduling, because visible=true
            // may not fire the closure here, when the view starts slightly in view at the screen edge.
            // We still use it to re-start after visibility-based cancellations.

            if isVisible {
                // Re-arm after a previous cancellation when the same cell re-enters view.
                startVisibilityTaskIfNeeded()
            } else {
                visibilityTask?.cancel()
                visibilityTask = nil
            }
        }
        .task {
            startVisibilityTaskIfNeeded()
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
    MediaFileThumbImage(.makeRandomUploaded(id: "1", .horizontalImage))
        .frame(width: 200, height: 200)
        .clipped()

}
