//
//  ZoomableScrollView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 26.09.25.
//

import SwiftUI

// Kudos to this technique (adapted) from: https://github.com/Dimillian/IceCubesApp/blob/d22e7b93389c3407d2d95d74be99a5f3c6b75857/Packages/MediaUI/Sources/MediaUI/MediaUIZoomableContainer.swift#L30
// and also: https://stackoverflow.com/questions/74238414/is-there-an-easy-way-to-pinch-to-zoom-and-drag-any-view-in-swiftui

struct ZoomableScrollView<Content: View>: UIViewRepresentable {

    @Binding var zoom: CGFloat
    @Binding var isZooming: Bool
    @Binding var doubleTap: CGPoint?
    let maxZoom: Double

    @ViewBuilder var content: Content


    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .clear
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = maxZoom
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
            zoom: $zoom,
            isZooming: $isZooming
        )
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostingController.rootView = content

        if uiView.zoomScale > uiView.minimumZoomScale {  // Scale out
            uiView.setZoomScale(zoom, animated: true)
        } else if let doubleTap, doubleTap != .zero {  // Scale in to a specific point
            uiView.zoom(
                to: zoomRect(for: uiView, scale: uiView.maximumZoomScale, center: doubleTap),
                animated: true)
        } else if uiView.zoomScale < zoom {
            uiView.setZoomScale(zoom, animated: true)
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
        @Binding var zoom: CGFloat
        @Binding var isZooming: Bool

        init(hostingController: UIHostingController<Content>, zoom: Binding<CGFloat>, isZooming: Binding<Bool>) {
            self.hostingController = hostingController
            self._zoom = zoom
            self._isZooming = isZooming
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController.view
        }

        func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
            Task { @MainActor in
                self.isZooming = true
            }
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            Task { @MainActor in
                self.zoom = scrollView.zoomScale
            }
        }


        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            self.zoom = scale
            let rounded = scale.rounded()

            Task { @MainActor in
                if rounded == 1, rounded != scale, abs(rounded - scale) < 0.1 {
                    // if we end up with a zoom factor of almost 1 but not quite,
                    //we ease the zoom into that full number for better UX when dragging to close.
                    scrollView.setZoomScale(rounded, animated: true)
                } else {
                    self.isZooming = false
                }
            }
        }
    }
}
