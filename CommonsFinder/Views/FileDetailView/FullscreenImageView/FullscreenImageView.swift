//
//  FullscreenImageView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 23.09.25.
//

import CoreGraphics
import NukeUI
import SwiftUI
import UIKit

struct FullscreenImageView: View {
    let mediaFileInfo: MediaFileInfo
    let namespace: Namespace.ID

    @Binding var isPresented: Bool

    @State private var isVisible = false
    @State private var isHudEnabled = false

    @GestureState private var currentClosingTranslation: CGSize?
    @State private var finalClosingTranslation: CGSize?

    @State private var zoom: CGFloat = 1.0
    @State private var isZooming = false
    @State private var lastDoubleTap: CGPoint?
    @State private var closingThresholdTrigger = 0.0

    let maxZoom = 5.0

    var closingTranslation: CGSize {
        currentClosingTranslation ?? finalClosingTranslation ?? .zero
    }

    let closingTranslationThreshold = 100.0

    var userHasZoomedIn: Bool {
        zoom != 1
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
                    isHudEnabled = false
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
                zoom = zoom == 1 ? maxZoom : 1
            } else {
                isHudEnabled.toggle()
            }
        }

        ZStack {
            Color(white: 0, opacity: backgroundOpacity)
            ZoomableScrollView(zoom: $zoom, isZooming: $isZooming, doubleTap: $lastDoubleTap, maxZoom: maxZoom) {
                imageView.background(Color.clear)
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
        .ignoresSafeArea()
        .transaction(value: closingTranslation) { transaction in
            if transaction.isDragging {
                transaction.animation = .interactiveSpring()
            } else {
                // When the @GestureState resets the offset to 0
                transaction.animation = .spring
            }
        }
        .presentationBackground(.clear)
        .statusBarHidden()
        .onAppear {
            guard !isVisible else { return }
            withAnimation(.snappy) { isVisible = true }
        }
        .animation(.default) { content in
            let shouldRenderCloseButton =
                isVisible && isHudEnabled && closingTranslation == .zero

            content
                .overlay(alignment: .topTrailing) {
                    if shouldRenderCloseButton {
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
                .overlay(alignment: .topLeading) {
                    let shouldRenderZoomButton =
                        isVisible && (isHudEnabled || isZooming) && closingTranslation == .zero

                    if shouldRenderZoomButton {
                        Button {
                            zoom = zoom == 1 ? maxZoom : 1
                        } label: {
                            let displayDecimalPlace = floor(zoom) != zoom
                            Text("\(zoom, specifier: "%.\(displayDecimalPlace ? 1 : 0)f")\(Image(systemName: "multiply"))")
                                .contentTransition(.numericText(value: zoom))
                                .frame(height: 34)
                        }
                        .glassButtonStyle()
                        .padding(.horizontal)
                    }
                }

        }

    }

    private var imageView: some View {
        LazyImage(request: mediaFileInfo.largeResizedRequest) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if let thumbRequest = mediaFileInfo.thumbRequest {
                LazyImage(request: thumbRequest) { phase in
                    Group {
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            Color.clear
                        }
                    }
                    .overlay {
                        ProgressView().progressViewStyle(.circular)
                    }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    @Previewable @Namespace var namespace
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
    .fullscreenImageCover(mediaFileInfo: mediaFileInfo, namespace: namespace, isPresented: $isPresented)
}
