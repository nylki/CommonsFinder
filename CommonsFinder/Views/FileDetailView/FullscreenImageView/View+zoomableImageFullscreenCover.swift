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

private struct FullscreenImageOverlay: ViewModifier {
    let mediaFileInfo: MediaFileInfo
    let namespace: Namespace.ID
    @Binding var isPresented: Bool


    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented) {
                ZoomableImageView(mediaFileInfo: mediaFileInfo, namespace: namespace, isPresented: $isPresented)
            }
            .transaction(value: isPresented) {
                /// Opens the fullscreenCover without the regular animation
                /// to have more control over speed and type of the animated transition.
                $0.disablesAnimations = true
            }
    }
}
