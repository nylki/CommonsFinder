//
//  View+zoomableImageFullscreenCover.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 25.09.25.
//

import NukeUI
import SwiftUI

extension View {
    func zoomableImageFullscreenCover(
        imageReference: ZoomableImageReference?,
        isPresented: Binding<Bool>
    ) -> some View {
        modifier(
            FullscreenImageOverlay(
                imageReference: imageReference,
                isPresented: isPresented
            ))


    }
}


private struct FullscreenImageOverlay: ViewModifier {
    let imageReference: ZoomableImageReference?
    @Binding var isPresented: Bool


    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented) {
                if let imageReference {
                    ZoomableImageView(image: imageReference, isPresented: $isPresented)
                } else {
                    Text("Could not load image (this is a bug, please report :)")
                }
            }
            .transaction(value: isPresented) {
                /// Opens the fullscreenCover without the regular animation
                /// to have more control over speed and type of the animated transition.
                $0.disablesAnimations = true
            }
    }
}
