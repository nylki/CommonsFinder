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
    //    var info: MultiDraftInfo

    var multiDraft: MultiDraft
    var subDraftModels: [MediaFileDraft.ID: SingleDraftModel]
    var suggestedFilenames: [FileNameTypeTuple] = []
    var nameValidationResult: NameValidationResult?


    private var generateFilenameTask: Task<Void, Never>?

    var draftExistsInDB: Bool {
        multiDraft.id != nil
    }

    var choosenMapItems: [DraftMapItem] {
        return switch multiDraft.locationHandling {
        case .userDefinedLocation(latitude: let lat, longitude: let lon, _):
            [.init(latitude: lat, longitude: lon)]
        case .exifLocation:
            subDraftModels.values.compactMap { model in
                if let coordinate = exifData[model.id]?.coordinate {
                    .init(imageRequest: model.draft.localFileRequestResizedGridThumb, coordinate: coordinate)
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

    var filesCreatedInSpreadOutLocations: Bool {
        guard let radiusInDegrees = minimumBoundingCircleRadiusOfCoordinates else { return false }
        let diameterInMeters = GeoVectorMath.meters(fromDegrees: radiusInDegrees * 2)
        return diameterInMeters > ViewConstants.multiDraftMaxFileDistanceWarningThreshold
    }

    var filesCreatedOnDifferentDays: Bool {
        let dates = subDraftModels.values.map(\.draft.inceptionDate)
        guard let first = dates.first, dates.count >= 2 else { return false }
        return !dates.allSatisfy { Calendar.current.isDate($0, inSameDayAs: first) }
    }


    func validateFilenameImpl() async throws {
        // FIXME: combine with general .onChangeOf(draft)
        // and check conditionally if newValue.name != oldValue.name to validate filename
        nameValidationResult = nil
        multiDraft.uploadPossibleStatus = nil
        try await Task.sleep(for: .milliseconds(500))

        let finalFilenames: [String] = try subDraftModels.values.map {
            try FilenameUtils.finalFilename(for: $0.draft, in: multiDraft, totalFileCount: subDraftModels.count)
        }

        nameValidationResult = try await DraftValidation.validateBatchFilenames(filenamesWithSuffix: finalFilenames)
        let newStatus = DraftValidation.canUploadDraft(multiDraft, nameValidationResult: nameValidationResult)
        multiDraft.uploadPossibleStatus = newStatus
    }

    func delete(_ subDraftIDs: [MediaFileDraft.ID], appDatabase: AppDatabase) {
        do {
            _ = try appDatabase.deleteDrafts(ids: subDraftIDs)
            if let updated = try appDatabase.fetchMultiDraftInfo(id: multiDraft.id) {
                multiDraft = updated.multiDraft
                initSubDraftModels(from: updated.drafts)
            }
        } catch {
            logger.error("Failed to delete a sub-draft  with ids \(subDraftIDs), \(error)")
        }
    }

    func saveChanges(appDatabase: AppDatabase) {
        do {
            let updated = try appDatabase.upsertAndFetch(
                MultiDraftInfo(multiDraft: multiDraft, drafts: subDraftModels.values.map(\.draft))
            )

            multiDraft = updated.multiDraft
            initSubDraftModels(from: updated.drafts)
        } catch {
            logger.error("Failed to save all drafts \(error)")
        }
    }

    func startUpload(appDatabase: AppDatabase, uploadManager: UploadManager) {

        saveChanges(appDatabase: appDatabase)

        guard let id = multiDraft.id else {
            assertionFailure("We expect the draft to have been saved in DB and in effect having an ID.")
            return
        }

        uploadManager.upload(multiDraftWithID: id)
    }

    func generateFilename() {
        generateFilenameTask?.cancel()
        generateFilenameTask = Task<Void, Never> {
            guard let selectedFilenameType = multiDraft.selectedFilenameType else {
                return
            }

            try? await Task.sleep(for: .milliseconds(250))

            let generatedFilename =
                await selectedFilenameType.generateFilename(
                    coordinate: centroidCoordinate,
                    date: subDraftModels.values.first?.draft.inceptionDate,
                    desc: multiDraft.captionWithDesc,
                    locale: Locale.current,
                    tags: multiDraft.tags
                ) ?? multiDraft.name

            guard !Task.isCancelled else {
                generateFilenameTask = nil
                return
            }

            multiDraft.name = generatedFilename
        }
    }

    func copyFieldsIntoSubDrafts(appDatabase: AppDatabase) {
        guard multiDraft.uploadPossibleStatus == .uploadPossible else {
            return
        }
        for subDraftModel in subDraftModels.values {
            subDraftModel.draft.name =
                (try? FilenameUtils.finalFilename(
                    for: subDraftModel.draft,
                    in: multiDraft,
                    totalFileCount: subDraftModels.count,
                    withFileExtension: false)) ?? ""

            subDraftModel.draft.captionWithDesc = multiDraft.captionWithDesc
            subDraftModel.draft.tags = multiDraft.tags
            subDraftModel.draft.uploadPossibleStatus = .uploadPossible
            subDraftModel.draft.selectedFilenameType = .custom
            subDraftModel.draft.license = multiDraft.license
            subDraftModel.draft.author = multiDraft.author
            subDraftModel.draft.source = multiDraft.source
            subDraftModel.draft.locationHandling = multiDraft.locationHandling
        }

        multiDraft.copiedFieldsIntoSubDrafts = true
        saveChanges(appDatabase: appDatabase)
    }

    @ObservationIgnored
    lazy var exifData: [MediaFileDraft.ID: ExifData] = {
        var result: [MediaFileDraft.ID: ExifData] = [:]
        for subDraftModel in subDraftModels.values {
            if let exifData = subDraftModel.draft.loadExifData() {
                result[subDraftModel.id] = exifData
            }
        }
        return result
    }()

    func initSubDraftModels(from drafts: [MediaFileDraft]) {
        var subDraftModels: [MediaFileDraft.ID: SingleDraftModel] = [:]
        for draft in drafts {
            subDraftModels[draft.id] = SingleDraftModel(existingDraft: draft)
        }
        self.subDraftModels = subDraftModels
    }


    init(_ info: MultiDraftInfo) {
        id = UUID().uuidString
        multiDraft = info.multiDraft
        self.subDraftModels = [:]
        initSubDraftModels(from: info.drafts)
        nameValidationResult = nil
    }
}
