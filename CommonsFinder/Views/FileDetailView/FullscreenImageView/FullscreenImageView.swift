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
    @State private var isHUDEnabled = false

    @GestureState private var currentClosingTranslation: CGSize?
    @State private var finalClosingTranslation: CGSize?

    @State private var magnification: CGFloat = 1.0
    @State private var lastDoubleTap: CGPoint?


    var closingTranslation: CGSize {
        currentClosingTranslation ?? finalClosingTranslation ?? .zero
    }

    var userHasZoomedIn: Bool {
        magnification != 1
    }

    var closingScale: CGFloat {
        if magnification != 1 {
            return magnification
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
        guard magnification == 1 else { return 1 }
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
            .onEnded { value in
                let endTranslation = value.predictedEndTranslation

                if endTranslation.magnitude() > 100, !userHasZoomedIn {
                    isHUDEnabled = false
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
                magnification = magnification == 1 ? 5 : 1
            } else {
                isHUDEnabled.toggle()
            }
        }

        ZStack {
            Color(white: 0, opacity: backgroundOpacity)
            ZoomableScrollView(scale: $magnification, doubleTap: $lastDoubleTap) {
                imageView
                    .background(Color.clear)
            }
            .offset(closingTranslation)
            //        .scaleEffect(closingScale)
            .rotationEffect(closingRotation)
            .opacity(isVisible ? 1 : 0)
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
        .animation(.easeInOut) { content in
            let shouldRenderHUD =
                isVisible && isHUDEnabled && closingTranslation == .zero

            content.overlay(alignment: .top) {
                if shouldRenderHUD { HUD }
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

    private var HUD: some View {
        VStack {
            HStack {
                Button {
                    magnification = magnification == 1 ? 5 : 1
                } label: {
                    Text("\(magnification, specifier: "%.1f")x")
                        .contentTransition(.numericText(value: magnification))
                }
                .buttonStyle(.glass)
                .padding()

                Spacer()
                Button {
                    exitFullscreen()
                } label: {
                    Label("close", systemImage: "xmark")
                        .frame(width: 26, height: 34)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)

                .transition(.blurReplace)
            }

            Spacer()
        }
        .ignoresSafeArea()
        .padding()


    }
}

#Preview {
    @Previewable @State var isPresented = true
    @Previewable @Namespace var namespace

    let mediaFileInfo = MediaFileInfo(mediaFile: .makeRandomUploaded(id: "1", .squareImage))

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
