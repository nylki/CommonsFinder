//
//  MultiDraft.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.03.26.
//

import Foundation
import GRDB

/// A container type storing attributes that will be used for its sub/child-MediaFileDrafts
/// for relevant views and for uploading.
nonisolated struct MultiDraft: Draftable, Identifiable, Equatable, Hashable {
    typealias MultiDraftID = Int64

    let id: MultiDraftID?
    let addedDate: Date
    /// The (base-)name is used to construct individual file names by adding the nameSuffix
    var name: String
    var nameSuffix: MultiFileNameSuffix
    /// if name+nameSuffix is already taken, this suffix will be appended additionally if possible
    var nameAdditionalFallbackSuffix: MultiFileFallbackSuffix

    var captionWithDesc: [CaptionWithDescription]
    var tags: [TagItem]
    var license: DraftMediaLicense?
    var author: DraftAuthor?
    var source: DraftSource?
    var locationHandling: LocationHandling?

    var locationEnabled: Bool {
        get { locationHandling == .exifLocation }
        set { locationHandling = newValue ? .exifLocation : .noLocation }
    }

    var selectedFilenameType: FileNameType
    var uploadPossibleStatus: UploadPossibleStatus?

    /// tracks the overall publishing state of a multi-upload that is in progress or has finished.
    /// the more detailed per-file publishing state is stored in the individial MediaFileDraft items.
    var publishingState: PublishingState?

    enum MultiFileNameSuffix: Equatable, Hashable, Codable {
        /// eg. 001, 002 .... 999
        case numberingZeroPadded
        /// eg. 1, 2 .... 999
        case numbering
    }

    enum MultiFileFallbackSuffix: Equatable, Hashable, Codable {
        /// from B to Z
        case asciiLetters
    }

    struct PublishingState: Equatable, Hashable, Codable {
        /// This is an aggregated progress of all uploads, succesfull or failed, normalized to 0....1,
        ///  The same value is display via tzhe BGProcessingTask that shows in the Dynamic Island
        var overallProgress: Double

        /// This will `true` after all files have been processed, no matter
        /// whether errors did occor on some files or not.
        var isFinished: Bool

        var completedCount: Int

        /// usually this would match the amount of linked sub-drafts
        /// it may differ if the upload was re-started by the user after errors occured
        /// and some files are already successfully uploaded, but not all.
        var totalCount: Int
    }
}


extension MultiDraft {
    init(newDraftOptions: NewDraftOptions?) {
        id = nil
        addedDate = .now
        name = ""
        nameSuffix = .numbering
        nameAdditionalFallbackSuffix = .asciiLetters

        let languageCode = Locale.current.wikiLanguageCodeIdentifier
        captionWithDesc = [.init(languageCode: languageCode)]

        if let initialTag = newDraftOptions?.tag {
            tags = [initialTag]
        } else {
            tags = []
        }

        license = UserDefaults.standard.defaultPublishingLicense
        author = .appUser
        source = .own

        locationHandling = .exifLocation
        selectedFilenameType = .captionAndDate
        uploadPossibleStatus = nil
    }
}


// MARK: - Database

/// Make MultiDraft a Codable Record.
///
///
///
/// See <https://github.com/groue/GRDB.swift/blob/master/README.md#records>
///
nonisolated extension MultiDraft: Codable, FetchableRecord, MutablePersistableRecord {
    static let drafts = hasMany(MediaFileDraft.self).forKey("drafts")

    enum CodingKeys: CodingKey {
        case id
        case addedDate
        case name
        case nameSuffix
        case nameAdditionalFallbackSuffix
        case captionWithDesc
        case tags
        case license
        case author
        case source
        case locationHandling
        case selectedFilenameType
        case publishingState
        case uploadPossibleStatus

    }

    // Define database columns from CodingKeys
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let addedDate = Column(CodingKeys.addedDate)
    }
}
