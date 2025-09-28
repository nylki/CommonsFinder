//
//  ZoomableScrollView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 26.09.25.
//

import SwiftUI
import UIKit

// Kudos to this technique: https://github.com/Dimillian/IceCubesApp/blob/d22e7b93389c3407d2d95d74be99a5f3c6b75857/Packages/MediaUI/Sources/MediaUI/MediaUIZoomableContainer.swift#L30
// and also: https://stackoverflow.com/questions/74238414/is-there-an-easy-way-to-pinch-to-zoom-and-drag-any-view-in-swiftui

struct ZoomableScrollView<Content: View>: UIViewRepresentable {

    private var content: Content
    @Binding private var doubleTap: CGPoint?
    @Binding private var scale: CGFloat

    init(scale: Binding<CGFloat>, doubleTap: Binding<CGPoint?>, @ViewBuilder content: () -> Content) {
        self._scale = scale
        self._doubleTap = doubleTap
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .clear
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 5
        scrollView.minimumZoomScale = 1
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.clipsToBounds = false

        //      Create a UIHostingController to hold our SwiftUI content
        let hostedView = context.coordinator.hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = true
        hostedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostedView.frame = scrollView.bounds
        hostedView.backgroundColor = .clear
        scrollView.addSubview(hostedView)

        return scrollView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            hostingController: UIHostingController(rootView: self.content),
            scale: $scale
        )
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostingController.rootView = content

        if uiView.zoomScale > uiView.minimumZoomScale {  // Scale out
            uiView.setZoomScale(scale, animated: true)
        } else if let doubleTap, doubleTap != .zero {  // Scale in to a specific point
            uiView.zoom(
                to: zoomRect(for: uiView, scale: uiView.maximumZoomScale, center: doubleTap),
                animated: true)
        } else if uiView.zoomScale < scale {
            uiView.setZoomScale(scale, animated: true)
        }
        DispatchQueue.main.async { self.doubleTap = nil }
    }

    @MainActor func zoomRect(for scrollView: UIScrollView, scale: CGFloat, center: CGPoint)
        -> CGRect
    {
        let scrollViewSize = scrollView.bounds.size

        let width = scrollViewSize.width / scale
        let height = scrollViewSize.height / scale
        let x = center.x - (width / 2.0)
        let y = center.y - (height / 2.0)

        return CGRect(x: x, y: y, width: width, height: height)
    }

    class Coordinator: NSObject, UIScrollViewDelegate {

        var hostingController: UIHostingController<Content>
        @Binding var scale: CGFloat

        init(hostingController: UIHostingController<Content>, scale: Binding<CGFloat>) {
            self.hostingController = hostingController
            self._scale = scale
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController.view
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            DispatchQueue.main.async { self.scale = scrollView.zoomScale }
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            self.scale = scale
        }
    }
}
