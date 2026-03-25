//
//  MediaFileDraftModel+ImageRequest.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.12.25.
//


import Foundation
import Nuke

extension SingleDraftModel {
    var zoomableImageReference: ZoomableImageReference? {
        if let imageRequest {
            .localImage(.init(image: imageRequest, fullWidth: draft.width, fullHeight: draft.height, fullByte: nil))
        } else {

            nil

        }
    }

    var imageRequest: ImageRequest? {
        draft.localFileRequestFull
    }
}
