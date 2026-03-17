//
//  MultiDraftModel.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.03.26.
//


import CommonsAPI
import CoreLocation
import Foundation
import Nuke
import UniformTypeIdentifiers
import os.log

// TODO: perhaps consolidate as view state directly
@Observable final class MultiDraftModel: @preconcurrency Identifiable {
    typealias ID = String
    var id: ID
    var info: MultiDraftInfo

    var suggestedFilenames: [FileNameTypeTuple] = []
    var nameValidationResult: [MediaFileDraft.ID: NameValidationResult]
    
    var choosenCoordinates: [CLLocationCoordinate2D] {
        return switch info.multiDraft.locationHandling {
        case .userDefinedLocation(latitude: let lat, longitude: let lon, _):
            [.init(latitude: lat, longitude: lon)]
        case .exifLocation:
            exifData.values.compactMap(\.coordinate)
        case .noLocation:
            []
        case .none:
            []
        }
    }

    @ObservationIgnored
    lazy var exifData: [MediaFileDraft.ID: ExifData] = {
        var result: [MediaFileDraft.ID: ExifData] = [:]
        for draft in info.drafts {
            if let exifData = draft.loadExifData() {
                result[draft.id] = exifData
            }
        }
        return result
    }()


    init(_ info: MultiDraftInfo) {
        id = UUID().uuidString
        self.info = info
        nameValidationResult = [:]
    }
}
