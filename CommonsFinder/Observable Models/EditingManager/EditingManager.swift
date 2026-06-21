//
//  EditingManager.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 06.02.26.
//

import CommonsAPI
import Foundation
import os.log

@Observable final class EditingManager {
    var status: [MediaFile.ID: EditingStatus] = [:]

    @ObservationIgnored
    private var tasks: [MediaFile.ID: Task<Void, Error>] = [:]

    private let appDatabase: AppDatabase

    init(appDatabase: AppDatabase) {
        self.appDatabase = appDatabase
    }

    /// Will first await for authentication, then quickly start the network calls in a new Task to return early.
    func startPublishChanges(of model: EditedMediaFile) async throws {
        // NOTE: we pre-emptively authenticate here, to avoid this error in the caller:
        // "Attempted to present SFAuthenticationViewController from a view controller that is being dismissed"
        try await Networking.shared.authenticate()

        let mediaFile = model.referenceMediaFileInfo.mediaFile
        let id = mediaFile.id

        tasks[id]?.cancel()
        tasks[id] = nil

        let selectedTags = model.tags
        let selectedCategories = PublishHelpers.selectedCategoryNames(from: selectedTags)
        let selectedDepicts = PublishHelpers.selectedDepictItemIDs(from: selectedTags)

        let knownCategorySet = Set(
            model.referenceTags
                .filter { $0.pickedUsages.contains(.category) }
                .compactMap { $0.baseItem.commonsCategory }
                .map(PublishHelpers.normalizedCategoryName)
        )
        let selectedCategorySet = Set(selectedCategories.map(PublishHelpers.normalizedCategoryName))
        let referenceCategorySet = Set(
            model.referenceTags
                .filter { $0.pickedUsages.contains(.category) }
                .compactMap { $0.baseItem.commonsCategory }
                .map(PublishHelpers.normalizedCategoryName)
        )

        let selectedDepictSet = Set(selectedDepicts.map(\.id))
        let referenceDepictSet = Set(
            model.referenceTags
                .filter { $0.pickedUsages.contains(.depict) }
                .compactMap { $0.baseItem.wikidataId }
        )

        let trimmedCaptions = model.captions.compactMap { caption -> LanguageString? in
            let trimmed = caption.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return .init(trimmed, languageCode: caption.languageCode)
        }
        let trimmedReferenceCaptions = model.referenceCaptions.compactMap { caption -> LanguageString? in
            let trimmed = caption.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return .init(trimmed, languageCode: caption.languageCode)
        }

        let captionsChanged = trimmedCaptions != trimmedReferenceCaptions
        let depictsChanged = selectedDepictSet != referenceDepictSet
        let categoriesChanged = selectedCategorySet != referenceCategorySet

        guard categoriesChanged || captionsChanged || depictsChanged else {
            logger.warning("Tried to publish no changes. This should be disabled in the UX, otherwise this may indicate an issue determining changes.")
            return
        }

        tasks[id] = Task<Void, Error> {
            status[id] = .editing

            do {
                if captionsChanged || depictsChanged {
                    let entityId = mediaFile.entityId
                    let labelChanges = PublishHelpers.labelDiff(current: trimmedReferenceCaptions, target: trimmedCaptions)

                    let summary = "edited with \(Networking.shared.editAndUploadCommentSuffix)"

                    for label in labelChanges.set {
                        try await Networking.shared.api.setLabel(
                            entityId: entityId,
                            language: label.languageCode,
                            value: label.string,
                            summary: summary
                        )
                    }

                    for language in labelChanges.remove {
                        try await Networking.shared.api.setLabel(
                            entityId: entityId,
                            language: language,
                            value: nil,
                            summary: summary
                        )
                    }

                    let existingDepicts = mediaFile.statements.filter(\.isDepicts)
                    var existingByItemID: [String: WikidataClaim] = [:]
                    for claim in existingDepicts {
                        if let id = claim.mainItem?.id {
                            existingByItemID[id] = claim
                        }
                    }

                    let existingDepictSet = Set(existingByItemID.keys)
                    let depictsToAdd = selectedDepictSet.subtracting(existingDepictSet)
                    let depictsToRemove = existingDepictSet.subtracting(selectedDepictSet)

                    for itemId in depictsToAdd {
                        guard let wikidataItem = WikidataItemID(stringValue: itemId) else { continue }
                        try await Networking.shared.api.createClaim(
                            entityId: entityId,
                            property: .depicts,
                            value: wikidataItem,
                            summary: summary
                        )
                    }

                    for itemId in depictsToRemove {
                        guard let claimId = existingByItemID[itemId]?.id else { continue }
                        try await Networking.shared.api.removeClaim(
                            claimId: claimId,
                            summary: summary
                        )
                    }
                }

                if categoriesChanged {
                    let wikitext = try await Networking.shared.api.fetchPageWikitext(pageID: mediaFile.id)

                    let updatedText = PublishHelpers.updateCategories(
                        in: wikitext,
                        selectedCategories: selectedCategories,
                        knownCategories: knownCategorySet
                    )
                    let referenceCategories = model.referenceTags
                        .filter { $0.pickedUsages.contains(.category) }
                        .compactMap { $0.baseItem.commonsCategory }
                    let summary = PublishHelpers.categoryEditSummary(
                        selectedCategories: selectedCategories,
                        referenceCategories: referenceCategories
                    )
                    try await Networking.shared.api.editPageText(
                        pageID: mediaFile.id,
                        text: updatedText,
                        summary: summary
                    )
                }
                status[id] = .finishedAndPerformingRefresh
                let refreshed = try await Networking.shared.api.fetchFullFileMetadata(.pageids([mediaFile.id])).first

                if let refreshed {
                    let refreshedMediaFile = MediaFile(apiFileMetadata: refreshed)
                    try appDatabase.upsert([refreshedMediaFile])
                }
                status[id] = nil

            } catch {
                logger.error("Failed to publish media file edits \(error)")

                status[id] = .error(error)
            }
        }
    }
}
