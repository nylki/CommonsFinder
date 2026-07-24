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
///
/// IMPORTANT: All sub-drafts (MediaFileDraft) of a MultiDraft have nil/blank fields by default. The values of the linked MultiDraft
/// (via multiDraftId) are used during upload.
/// However both MultiDraft and MediaFileDraft are designed, so that fields in a sub-MediaFileDraft can "customized", by filling the fields
/// with values that would otherwise be copied from the parent MultiDraft.
/// Not all fields may actually be customizable yet in UI, but the intend is to be able to do that in future polishing passes,
/// so that the user can eg. adjust captions, filenames and categories.

nonisolated struct MultiDraft: Draftable, Identifiable, Equatable, Hashable {
    typealias MultiDraftID = Int64

    let id: MultiDraftID?
    let addedDate: Date
    /// The (base-)name is used to construct individual file names by adding the nameSuffix
    var name: String
    var nameSuffix: MultiFileNameSuffix

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

    var selectedFilenameType: FileNameType?
    var uploadPossibleStatus: UploadPossibleStatus?

    /// tracks the overall publishing state of a multi-upload that is in progress or has finished.
    /// the more detailed per-file publishing state is stored in the individial MediaFileDraft items.
    var publishingState: PublishingState?

    /// After this is set to `true`, the shared fields in `MultiDraft` are expected to have been copied
    /// to all sub-drafts.
    /// The UI uses `copiedFieldsIntoSubDrafts` to present the review view where
    /// the sub-drafts can be edited individually before uploading, to make final adjustments.
    var copiedFieldsIntoSubDrafts: Bool

    enum MultiFileNameSuffix: Equatable, Hashable, Codable {
        /// eg. 001, 002 .... 999
        case numberingZeroPadded
        /// eg. 1, 2 .... 999
        case numbering
    }

    struct PublishingState: Equatable, Hashable, Codable {
        /// This is an aggregated progress of all uploads, succesfull or failed, normalized to 0....1,
        ///  The same value is display via the BGContinuedProcessingTask that shows in the Dynamic Island
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
        selectedFilenameType = nil
        uploadPossibleStatus = nil

        copiedFieldsIntoSubDrafts = false
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
        case captionWithDesc
        case tags
        case license
        case author
        case source
        case locationHandling
        case selectedFilenameType
        case publishingState
        case uploadPossibleStatus
        case copiedFieldsIntoSubDrafts

    }

    // Define database columns from CodingKeys
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let addedDate = Column(CodingKeys.addedDate)
    }
}
