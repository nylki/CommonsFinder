//
//  ViewConstants.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 16.09.25.
//

import CoreLocation
import SwiftUI

nonisolated struct ViewConstants {
    static let draftImageCarouselContainerShape: RoundedRectangle = .rect(cornerRadius: 15)
    static let mapSheetContainerShape: RoundedRectangle = .rect(cornerRadius: 33)

    /// the maximum width or height of a zoomable image
    static let maxFullscreenLengthPx = 50_000

    // in byte
    static let maxFileSize = 150_000_000


    // FIXME: should be dynamic based on resolution (imagePixel / screen pixel) min 5 or something
    static let maxZoomFactor = 10.0

    static let multiDraftMaxFileDistanceWarningThreshold: CLLocationDistance = 2000
}
