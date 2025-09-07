//
//  MediaFileDraftModel.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 13.10.24.
//

import CommonsAPI
import Foundation
import Nuke
import Vision
import os.log

/// Represents the data to allow editing either a DB-backed MediaFile or a newly created one.
@Observable final class MediaFileDraftModel: @preconcurrency Identifiable {
    typealias ID = String
    var id: ID
    var draft: MediaFileDraft
    let addedDate: Date

    var isShowingStatementPicker = false
    var isShowingCategoryPicker = false
    var analysisResult: DraftAnalysisResult?

    /// If a draft has just been created and does not have its media file backed on disk in the apps directory
    /// this holds the information about filename, filetype and Data.
    var fileItem: FileItem?

    @ObservationIgnored
    lazy var exifData: ExifData? = {
        draft.loadExifData()
    }()

    init(fileItem: FileItem) {
        addedDate = .now
        let draft = MediaFileDraft(fileItem)
        self.id = fileItem.id
        self.draft = draft
        self.fileItem = fileItem
    }

    /// Use an already fully initialized draft
    init(existingDraft: MediaFileDraft) {
        addedDate = .now
        id = existingDraft.id
        draft = existingDraft
    }

    // TODO: always copy to disk. Because re-opening drafts will also read from Disk.
    private var imageLoadTask: Task<Void, Never>?

    // TODO: move to parent, to handle potentially multiple drafts at once
    func analyzeImage() async {
        guard analysisResult == nil else { return }

        logger.debug("analyzing draft image...")
        let result = await DraftAnalysis.analyze(draft: draft)
        logger.debug("analyzing draft image finished! \(result?.debugDescription ?? "")")
        self.analysisResult = result
    }
}

extension MediaFileDraftModel {
    var temporaryFilePath: URL? {
        fileItem?.fileURL
    }

    var temporaryFileImageRequest: ImageRequest? {
        if let temporaryFilePath {
            ImageRequest(url: temporaryFilePath)
        } else {
            nil
        }
    }
}
