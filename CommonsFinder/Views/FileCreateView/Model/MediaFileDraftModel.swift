//
//  MediaFileDraftModel.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 13.10.24.
//

import CommonsAPI
import Foundation
import Nuke

/// Represents the data to allow editing either a DB-backed MediaFile or a newly created one.
@Observable
@MainActor final class MediaFileDraftModel: @preconcurrency Identifiable {
    typealias ID = String
    var id: ID
    var draft: MediaFileDraft
    let addedDate: Date

    var isShowingStatementPicker = false
    var isShowingCategoryPicker = false

    /// If a draft has just been created and does not have its media file backed on disk in the apps directory
    /// this holds the information about filename, filetype and Data.
    var fileItem: FileItem?


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
