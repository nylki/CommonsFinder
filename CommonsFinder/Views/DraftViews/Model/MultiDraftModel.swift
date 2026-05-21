//
//  MultiDraftModel.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.03.26.
//


import CommonsAPI
import CoreLocation
import Foundation
import GEOSwift
import GEOSwiftMapKit
import Nuke
import UniformTypeIdentifiers
import os.log

// TODO: perhaps consolidate as view state directly, because a dedicated @observable model doesn't provide a benefit with the current setup, same for single draft model (!)
@Observable final class MultiDraftModel: @preconcurrency Identifiable {
    typealias ID = String
    var id: ID
    var info: MultiDraftInfo

    var suggestedFilenames: [FileNameTypeTuple] = []
    var nameValidationResult: NameValidationResult?

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

    var centroidCoordinate: CLLocationCoordinate2D? {
        let points: GEOSwift.MultiPoint = .init(points: choosenCoordinates.compactMap(Point.init))
        if let centroid = try? points.centroid() {
            return .init(centroid)
        } else {
            return nil
        }
    }

    var minimumBoundingCircleRadiusOfCoordinates: Double? {
        let points: GEOSwift.MultiPoint = .init(points: choosenCoordinates.compactMap(Point.init))
        return try? points.minimumBoundingCircle().radius
    }


    func validateFilenameImpl() async throws {
        nameValidationResult = nil
        info.multiDraft.uploadPossibleStatus = nil
        try await Task.sleep(for: .milliseconds(500))

        // FIXME: actually validate


        let finalFilenames: [String] =
            try FilenameUtils
            .generateMultiDraftFinalFilenames(multiDraftInfo: info)
            .map(\.value)


        nameValidationResult = try await DraftValidation.validateBatchFilenames(filenamesWithSuffix: finalFilenames)
        info.multiDraft.uploadPossibleStatus = DraftValidation.canUploadDraft(info.multiDraft, nameValidationResult: nameValidationResult)
    }

    func saveChanges(appDatabase: AppDatabase) {
        do {
            info = try appDatabase.upsertAndFetch(info)
        } catch {
            logger.error("Failed to save all drafts \(error)")
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
        nameValidationResult = nil
    }
}
