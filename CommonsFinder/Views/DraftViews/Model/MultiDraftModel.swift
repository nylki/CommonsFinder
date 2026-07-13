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

    var choosenMapItems: [DraftMapItem] {
        return switch info.multiDraft.locationHandling {
        case .userDefinedLocation(latitude: let lat, longitude: let lon, _):
            [.init(latitude: lat, longitude: lon)]
        case .exifLocation:
            self.info.drafts.compactMap { draft in
                if let coordinate = exifData[draft.id]?.coordinate {
                    .init(id: draft.id, imageRequest: draft.localFileRequestResizedGridThumb, coordinate: coordinate)
                } else {
                    nil
                }
            }


        case .noLocation:
            []
        case .none:
            []
        }
    }

    var centroidCoordinate: CLLocationCoordinate2D? {
        let points: GEOSwift.MultiPoint = .init(points: choosenMapItems.map(\.coordinate).compactMap(Point.init))
        if let centroid = try? points.centroid() {
            return .init(centroid)
        } else {
            return nil
        }
    }

    var minimumBoundingCircleRadiusOfCoordinates: Double? {
        let points: GEOSwift.MultiPoint = .init(points: choosenMapItems.map(\.coordinate).compactMap(Point.init))
        return try? points.minimumBoundingCircle().radius
    }


    func validateFilenameImpl() async throws {
        nameValidationResult = nil
        info.multiDraft.uploadPossibleStatus = nil
        try await Task.sleep(for: .milliseconds(500))

        let finalFilenames: [String] =
            try FilenameUtils
            .generateMultiDraftFinalFilenames(multiDraftInfo: info)
            .map(\.value)


        nameValidationResult = try await DraftValidation.validateBatchFilenames(filenamesWithSuffix: finalFilenames)
        info.multiDraft.uploadPossibleStatus = DraftValidation.canUploadDraft(info.multiDraft, nameValidationResult: nameValidationResult)
    }

    func delete(_ subDraftIDs: [MediaFileDraft.ID], appDatabase: AppDatabase) {
        do {
            _ = try appDatabase.deleteDrafts(ids: subDraftIDs)
            if let updated = try appDatabase.fetchMultiDraftInfo(id: info.id) {
                info = updated
            }
        } catch {
            logger.error("Failed to delete a sub-draft  with ids \(subDraftIDs), \(error)")
        }

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
