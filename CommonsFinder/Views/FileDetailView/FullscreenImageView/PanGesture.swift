////
////  PanGesture.swift
////  CommonsFinder
////
////  Created by Tom Brewe on 25.09.25.
////
//
//import SwiftUI
//
//class PanRecognizer: UIPanGestureRecognizer {
//    var zoomScale: CGFloat = 1
//    var panOffset: CGSize = .zero
//
//    init() {
//        super.init(target: nil, action: nil)
//        minimumNumberOfTouches = 2
//    }
//
//
//    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
//        print("touchesMoved \(touches.count) zoom inside recognizer\(zoomScale)")
//
//        super.touchesMoved(touches, with: event)
//        guard state == .began || state == .changed else { return }
//        let translation = translation(of: touches)
//        panOffset += translation.scaled(by: zoomScale)
//
//        // Allow single touch pan, after panned first.
//        if minimumNumberOfTouches == 2 {
//            minimumNumberOfTouches = 1
//        }
//    }
//
//    private func translation(of touches: Set<UITouch>) -> CGSize {
//        // FIXME: use Accelerate
//        var averageLocation: CGPoint = touches.reduce(into: .zero) { result, touch in
//            result += touch.location(in: view)
//        }
//        var previousLocation: CGPoint = touches.reduce(into: .zero) { result, touch in
//            result += touch.previousLocation(in: view)
//        }
//        averageLocation.x /= CGFloat(touches.count)
//        averageLocation.y /= CGFloat(touches.count)
//
//        previousLocation.x /= CGFloat(touches.count)
//        previousLocation.y /= CGFloat(touches.count)
//
//        return .init(
//            width: averageLocation.x - previousLocation.x,
//            height: averageLocation.y - previousLocation.y
//        )
//    }
//}
//
//struct PanGesture: UIGestureRecognizerRepresentable {
//  @Binding var panOffset: CGSize
//
//  func makeUIGestureRecognizer(context: Context) -> PanRecognizer {
//      PanRecognizer()
//  }
//
//    func makeCoordinator(converter _: CoordinateSpaceConverter) -> Coordinator {
//      Coordinator()
//    }
//
//    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
//      @objc func gestureRecognizer(
//        _: UIGestureRecognizer,
//        shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
//      ) -> Bool { true }
//    }
//
//
//  func handleUIGestureRecognizerAction(
//    _ recognizer: PanRecognizer, context: Context
//  ) {
//      panOffset = recognizer.panOffset
//  }
//}
