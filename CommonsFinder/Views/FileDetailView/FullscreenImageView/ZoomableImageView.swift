//
//  ZoomableImageView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 23.09.25.
//

import CoreGraphics
import Network
import Nuke
import NukeUI
import SwiftUI
import TipKit
import UIKit
import os

enum NetworkStatus: String, Equatable, Hashable {
    case unsatisfied
    case undetermined
    case restricted
    case ok
}

private struct DraggingTransactionKey: TransactionKey {
    static let defaultValue = false
}


extension Transaction {
    fileprivate var isDragging: Bool {
        get { self[DraggingTransactionKey.self] }
        set { self[DraggingTransactionKey.self] = newValue }
    }
}

enum LoadedImageType: Equatable, Hashable {
    case none
    case thumbnail(PlatformImage)
    case resized(PlatformImage)
    case original(PlatformImage, cached: Bool)

    var isThumbnail: Bool { if case .thumbnail(_) = self { true } else { false } }
    var isResized: Bool { if case .resized(_) = self { true } else { false } }
    var isOriginal: Bool { if case .original(_, _) = self { true } else { false } }

    var image: PlatformImage? {
        return switch self {
        case .thumbnail(let platformImage),
            .resized(let platformImage),
            .original(let platformImage, _):
            platformImage
        case .none:
            nil
        }
    }

    var width: Int? {
        if let w = image?.size.width { Int(w) } else { nil }
    }
    var height: Int? {
        if let h = image?.size.height { Int(h) } else { nil }
    }
}

enum ZoomableImageReference {
    case localImage(localImageReference)
    case remoteImage(RemoteImageReference)
    var fullWidth: Int? {
        switch self {
        case .localImage(let ref): ref.fullWidth
        case .remoteImage(let ref): ref.fullWidth
        }
    }
    var fullHeight: Int? {
        switch self {
        case .localImage(let ref): ref.fullHeight
        case .remoteImage(let ref): ref.fullHeight
        }
    }
    var fullByte: Int? {
        switch self {
        case .localImage(let ref): ref.fullByte
        case .remoteImage(let ref): ref.fullByte
        }
    }
}

protocol BasicImageInfoProtocol {
    var fullWidth: Int? { get }
    var fullHeight: Int? { get }
    var fullByte: Int? { get }
}


struct localImageReference: BasicImageInfoProtocol {
    let image: ImageRequest
    let fullWidth: Int?
    let fullHeight: Int?
    let fullByte: Int?
}

struct RemoteImageReference: BasicImageInfoProtocol {
    let fullImage: ImageRequest
    /// alternative to original image if problematic due to file type or whatever
    let maxResizedRequest: ImageRequest?
    let largeResized: ImageRequest?
    let thumbnail: ImageRequest?

    let fullWidth: Int?
    let fullHeight: Int?
    let fullByte: Int?
}


struct ZoomableImageView: View {
    let image: ZoomableImageReference

    @Binding var isPresented: Bool

    @State private var isVisible = false
    @State private var canShowBottomHUD = false
    @State private var isHUDEnabledByUser = true

    @GestureState private var currentClosingTranslation: CGSize?
    @State private var finalClosingTranslation: CGSize?

    @State private var zoom: CGFloat = 1.0
    @State private var isZooming = false
    @State private var lastDoubleTap: CGPoint?
    @State private var closingThresholdTrigger = 0.0

    @State private var networkStatus: NetworkStatus = .undetermined

    @State private var loadedImage: LoadedImageType = .none
    @State private var originalImageTask: ImageTask?
    @State private var originalImageLoadedPercent: Int?

    @State private var explicitlyLoadFullImage = false

    private var closingTranslation: CGSize {
        currentClosingTranslation ?? finalClosingTranslation ?? .zero
    }

    private let closingTranslationThreshold = 100.0

    private var userHasZoomedIn: Bool {
        zoom != 1
    }

    private var shouldShowHUD: Bool {
        isHUDEnabledByUser && isVisible && closingTranslation == .zero
    }

    var closingScale: CGFloat {
        if zoom != 1 {
            return zoom
        } else if closingTranslation != .zero {
            return 1 - closingTranslation.magnitude() / 600
        } else {
            return 1
        }
    }

    var closingRotation: Angle {
        return if closingTranslation != .zero, !userHasZoomedIn {
            .degrees(closingTranslation.width / 30)
        } else {
            .zero
        }
    }

    var backgroundOpacity: Double {
        guard isVisible else { return 0 }
        guard zoom == 1 else { return 1 }
        guard let currentClosingTranslation else { return 1 }

        /// the threshold when the background is fully transparent (opacity = 0)
        let dragMinThres = 20.0
        let dragMaxThres = 300.0
        var magnitude = currentClosingTranslation.magnitude()
        // only start transparency after a certain threshold
        magnitude = max(0, magnitude - dragMinThres)
        return 1 - min(1, magnitude / dragMaxThres)
    }

    private func exitFullscreen() {
        withAnimation(.default, completionCriteria: .logicallyComplete) {
            isVisible = false
        } completion: {
            isPresented = false
        }
    }

    var body: some View {
        let closingDragGesture = DragGesture()
            .updating($currentClosingTranslation) { value, state, transaction in
                transaction.isDragging = true
                state = value.translation
            }
            .onChanged { value in
                guard !userHasZoomedIn else { return }
                let translation = value.translation.magnitude()

                let passedOverThreshold =
                    (translation > closingTranslationThreshold && closingThresholdTrigger < closingTranslationThreshold)
                    || (translation < closingTranslationThreshold && closingThresholdTrigger > closingTranslationThreshold)

                if passedOverThreshold {
                    closingThresholdTrigger = translation
                }
            }
            .onEnded { value in
                let endTranslation = value.predictedEndTranslation

                if !userHasZoomedIn, endTranslation.magnitude() > closingTranslationThreshold {
                    isHUDEnabledByUser = false
                    withAnimation {
                        finalClosingTranslation = endTranslation
                    }
                    exitFullscreen()
                }
            }

        let combinedTapGestures = SimultaneousGesture(
            TapGesture(count: 1),
            SpatialTapGesture(count: 2)
        )
        .onEnded { value in
            if let doupleTap = value.second {
                lastDoubleTap = doupleTap.location
                zoom = zoom == 1 ? ViewConstants.maxZoomFactor : 1
            } else {
                isHUDEnabledByUser.toggle()
            }
        }

        ZStack {
            Color(white: 0, opacity: backgroundOpacity)
                .ignoresSafeArea()

            ZoomableScrollView(zoom: $zoom, isZooming: $isZooming, doubleTap: $lastDoubleTap, maxZoom: ViewConstants.maxZoomFactor) {
                if let image = loadedImage.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            }
            .offset(closingTranslation)
            //        .scaleEffect(closingScale)
            .rotationEffect(closingRotation)
            .opacity(isVisible ? 1 : 0)
            .sensoryFeedback(
                .impact(flexibility: .soft, intensity: 0.5),
                trigger: closingThresholdTrigger
            )
            .highPriorityGesture(closingDragGesture, isEnabled: !userHasZoomedIn)


        }
        .gesture(combinedTapGestures)
        .transaction(value: closingTranslation) { transaction in
            if transaction.isDragging {
                transaction.animation = .interactiveSpring()
            } else {
                // When the @GestureState resets the offset to 0
                transaction.animation = .spring
            }
        }
        .overlay(alignment: .bottom) {
            bottomOverlay
        }
        .animation(.default) { content in
            content
                .overlay(alignment: .topTrailing) {

                    if shouldShowHUD {
                        Button {
                            exitFullscreen()
                        } label: {
                            Label("Close", systemImage: "xmark")
                                .frame(width: 26, height: 34)
                        }
                        .labelStyle(.iconOnly)
                        .glassButtonStyle()
                        .transition(.blurReplace)
                        .padding(.horizontal)
                    }
                }
        }
        .animation(.default) { content in
            content.overlay(alignment: .topLeading) {
                let shouldRenderZoomButton = shouldShowHUD || isZooming

                let removalTransition = isZooming ? .opacity.animation(.default.delay(1)) : AnyTransition(.opacity)

                if shouldRenderZoomButton {
                    Button {
                        zoom = zoom == 1 ? ViewConstants.maxZoomFactor : 1
                    } label: {
                        let displayDecimalPlace = floor(zoom) != zoom
                        Text("\(zoom, specifier: "%.\(displayDecimalPlace ? 1 : 0)f")×")
                            .contentTransition(.numericText(value: zoom))
                            .frame(height: 34)
                            .frame(minWidth: 26)
                    }
                    .glassButtonStyle()
                    .padding(.horizontal)
                    .transition(.asymmetric(insertion: .opacity, removal: removalTransition))
                }
            }
        }
        .presentationBackground(.clear)
        .statusBarHidden()
        .onAppear {
            guard !isVisible else { return }
            withAnimation(.snappy) { isVisible = true }
        }
        .task(priority: .high) {
            // If the original is cached, take the shortcut and directly show that instead of loading any fallback image
            // see: // see: https://kean-docs.github.io/nuke/documentation/nuke/accessing-caches

            switch image {
            case .localImage(let localImageReference):
                // if its a local image, we can directly load the full image
                await loadFullImage(localImage: localImageReference)

            case .remoteImage(let remoteImageReference):
                do {
                    var cachedRequest = remoteImageReference.fullImage
                    cachedRequest.options = .returnCacheDataDontLoad
                    let cachedImageResponse = try await ImagePipeline.shared
                        .imageTask(with: cachedRequest)
                        .response

                    loadedImage = .original(cachedImageResponse.image, cached: true)
                    logger.info("I: Loaded cached original")
                    return
                } catch {
                    logger.log("I: Could not load cached original")
                }


                // Load both fallback images in parallel (usually already in cache)
                var resizedTask: Task<Void, Never>?
                var thumbTask: Task<Void, Never>?

                let thumbRequest = remoteImageReference.thumbnail
                let resizedRequest = remoteImageReference.largeResized

                if let thumbRequest {
                    thumbTask = Task {
                        if let thumb = try? await ImagePipeline.shared.imageTask(with: thumbRequest).image,
                            loadedImage == .none
                        {
                            loadedImage = .thumbnail(thumb)
                        }
                    }
                }

                if let resizedRequest {
                    resizedTask = Task {
                        if let resized = try? await ImagePipeline.shared.imageTask(with: resizedRequest).image,
                            !loadedImage.isOriginal
                        {
                            loadedImage = .resized(resized)
                        }
                    }
                }

                let (_, _) = await (thumbTask?.result, resizedTask?.result)

            }
        }
        .task(priority: .medium) {
            guard !loadedImage.isOriginal else { return }
            guard case .remoteImage(let remoteImage) = image else { return }

            @MainActor
            func setNetworkStatus(basedOnPath path: NWPath) {
                let restricted = path.isConstrained || path.isExpensive
                if path.status == .unsatisfied {
                    networkStatus = .unsatisfied
                } else {
                    networkStatus = restricted ? .restricted : .ok
                }
            }

            let networkMonitor = NWPathMonitor()
            setNetworkStatus(basedOnPath: networkMonitor.currentPath)

            if networkStatus == .restricted {
                canShowBottomHUD = true
            } else {
                Task {
                    try? await Task.sleep(for: .milliseconds(1000))
                    canShowBottomHUD = true
                }
            }

            for await path in networkMonitor {
                setNetworkStatus(basedOnPath: path)
                guard !loadedImage.isOriginal else {
                    networkMonitor.cancel()
                    return
                }

                if networkStatus == .ok {
                    try? await Task.sleep(for: .milliseconds(100))
                    await loadFullImage(remoteImage: remoteImage)
                    // Once we have loaded the full image we are not interested in network updates anymore
                    // so we simply return.
                    networkMonitor.cancel()
                }
            }
        }
        .task(id: explicitlyLoadFullImage, priority: .userInitiated) {
            guard case .remoteImage(let remoteImage) = image else { return }
            if explicitlyLoadFullImage, originalImageTask == nil {
                await loadFullImage(remoteImage: remoteImage)
            }
        }
    }

    @ViewBuilder
    private var bottomOverlay: some View {
        // NOTE: unfortunatly the native .toolbar
        // when hidden/shown interferes with the gestures. Safe-Area offset?
        // Could investigate in the future.
        ZStack {
            if canShowBottomHUD, shouldShowHUD, let width = image.fullWidth, let height = image.fullHeight, let byte = image.fullByte {
                ResolutionButton(
                    width: width,
                    height: height,
                    byte: byte,
                    loadedImage: loadedImage,
                    networkStatus: networkStatus,
                    originalImageLoadedPercent: originalImageLoadedPercent,
                    onLoadOriginalImage: { explicitlyLoadFullImage = true }
                )
                .padding(.bottom)
                .transition(.offset(y: 20).combined(with: .blurReplace))
            }


        }
        .animation(.default, value: originalImageTask == nil)
        .animation(.default, value: shouldShowHUD)
        .animation(.default, value: canShowBottomHUD)


    }

    private func loadFullImage(localImage: localImageReference) async {
        guard originalImageTask == nil else { return }
        originalImageTask?.cancel()
        let originalImageTask = ImagePipeline.shared.imageTask(with: localImage.image)
        do {
            if let image = try? await originalImageTask.image {
                loadedImage = .original(image, cached: true)
            }
        } catch {
            logger.error("Failed to load local image \(error)")
        }
    }

    private func loadFullImage(remoteImage: RemoteImageReference) async {
        guard originalImageTask == nil else { return }
        originalImageTask?.cancel()

        let canUseOriginalFile: Bool

        canUseOriginalFile =
            if let size = remoteImage.fullByte,
                let w = remoteImage.fullWidth,
                let h = remoteImage.fullHeight,
                size < ViewConstants.maxFileSize,
                w < ViewConstants.maxFullscreenLengthPx,
                h < ViewConstants.maxFullscreenLengthPx
            { true } else { false }

        let request: ImageRequest? =
            if canUseOriginalFile {
                remoteImage.fullImage
            } else if let request = remoteImage.maxResizedRequest {
                request
            } else {
                nil
            }

        guard let request else { return }

        let originalImageTask = ImagePipeline.shared.imageTask(with: request)

        for await progress in originalImageTask.progress {
            guard !Task.isCancelled else {
                originalImageTask.cancel()
                return
            }
            let percent = Int(progress.fraction * 100)
            if percent != self.originalImageLoadedPercent {
                self.originalImageLoadedPercent = percent
                logger.debug("\(percent)% loaded.")
            }
        }

        do {
            let imageResponse = try await originalImageTask.response
            self.loadedImage = .original(imageResponse.image, cached: imageResponse.cacheType != nil)
        } catch {
            logger.error("Failed to load original remote image \(error)")
        }
        canShowBottomHUD = true

        self.originalImageTask = nil
    }
}

#Preview {
    @Previewable @State var isPresented = true
    let image = MediaFile.makeRandomUploaded(id: "1", .verticalImage)

    let mediaFileInfo = MediaFileInfo(mediaFile: image)

    VStack {
        LazyImage(request: mediaFileInfo.thumbRequest) {
            if let image = $0.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .onTapGesture {
            withAnimation(.linear(duration: 3)) {
                isPresented = true
            }

        }
        Spacer().frame(height: 300)

    }
    .zoomableImageFullscreenCover(
        imageReference: mediaFileInfo.zoomableImageReference,
        isPresented: $isPresented
    )
}
