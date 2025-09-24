//
//  FullscreenImageView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 23.09.25.
//

import Accelerate
import NukeUI
import SwiftUI

extension View {
    func fullscreenImageCover(
        mediaFileInfo: MediaFileInfo,
        namespace: Namespace.ID,
        isPresented: Binding<Bool>
    ) -> some View {
        modifier(
            FullscreenImageOverlay(
                mediaFileInfo: mediaFileInfo,
                namespace: namespace,
                isPresented: isPresented
            ))


    }
}

struct FullscreenImageOverlay: ViewModifier {
    let mediaFileInfo: MediaFileInfo
    let namespace: Namespace.ID
    @Binding var isPresented: Bool


    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented) {
                FullscreenImageView(mediaFileInfo: mediaFileInfo, namespace: namespace, isPresented: $isPresented)
            }
            .transaction(value: isPresented) {
                /// Opens the fullscreenCover without the regular animation
                /// to have more control over speed and type of the animated transition.
                $0.disablesAnimations = true
            }
    }
}


struct FullscreenImageView: View {
    let mediaFileInfo: MediaFileInfo
    let namespace: Namespace.ID


    @Binding var isPresented: Bool
    @State private var isVisible = false

    @GestureState private var dragTranslation = CGSize.zero
    @State private var isHUDVisible = false


    @State private var isExitingPosition: CGSize?

    var translation: CGSize {
        if let isExitingPosition {
            isExitingPosition
        } else {
            dragTranslation
        }
    }

    var scale: CGFloat {
        if let isExitingPosition {
            1 - vDSP.meanMagnitude([isExitingPosition.width, isExitingPosition.height]) / 600
        } else {
            1 - vDSP.meanMagnitude([dragTranslation.width, dragTranslation.height]) / 600
        }
    }

    var backgroundOpacity: Double {
        if isVisible == false {
            return 0
        }

        if dragTranslation == .zero {
            return 1
        }
        /// the threshold when the background is fully transparent (opacity = 0)

        let dragMinThres = 20.0
        let dragMaxThres = 300.0
        var magnitude = vDSP.meanMagnitude([dragTranslation.width, dragTranslation.height])
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

        let dragGesture = DragGesture(minimumDistance: 5)
            .updating($dragTranslation) { value, state, transaction in
                transaction.isDragging = true
                state = value.translation
            }
            .onEnded { value in
                let endTranslation = value.predictedEndTranslation
                let magnitude = vDSP.meanMagnitude([endTranslation.width, endTranslation.height])
                if magnitude > 100 {
                    isHUDVisible = false
                    withAnimation {
                        isExitingPosition = value.predictedEndTranslation
                    }
                    exitFullscreen()
                }
            }


        ZStack {
            Color(white: 0, opacity: backgroundOpacity)
            imageView
                .background(Color.clear)
                .contentShape(.rect)
                .geometryGroup()
                .compositingGroup()
                .opacity(isVisible ? 1 : 0)
                .scaleEffect(scale)
                .rotationEffect(.degrees(translation.width / 20))
                .offset(translation)

        }
        .ignoresSafeArea()
        .gesture(dragGesture)
        .transaction(value: translation) { transaction in
            if transaction.isDragging {
                print("isDragging")
                transaction.animation = .interactiveSpring()
            } else {
                print("isResetting")
                // When the @GestureState resets the offset to 0
                transaction.animation = .spring
            }
        }
        .onTapGesture {
            isHUDVisible.toggle()
        }
        .presentationBackground(.clear)
        .statusBarHidden()
        .onAppear(perform: {
            guard !isVisible else { return }

            withAnimation(.snappy) {
                isVisible = true
            }

        })
        .animation(.easeInOut) { content in
            let shouldRenderOverlay = isVisible && isHUDVisible && translation == .zero
            content.overlay(alignment: .topLeading) {
                if shouldRenderOverlay {
                    Button {
                        exitFullscreen()
                    } label: {
                        Label("close", systemImage: "xmark")
                            .frame(width: 26, height: 34)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .ignoresSafeArea()
                    .padding()
                    .transition(.blurReplace)
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
