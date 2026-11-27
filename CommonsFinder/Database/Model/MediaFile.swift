//
//  MediaFile.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 04.10.24.
//

import CommonsAPI
import CoreGraphics
import CoreLocation
import Foundation
import GRDB
import RegexBuilder
import UniformTypeIdentifiers

// Database Note:
// The SQLite DB table for MediaFile is defined in "AppDatabase"

nonisolated
    struct MediaFile: Equatable, Hashable, Sendable, Identifiable
{
    typealias LanguageCode = String

    /// pageID
    var id: String

    /// the revision ID of this version of the file
    var revid: Int?

    /// username of uploader
    var username: String

    /// The unique name without "File:"-prefix. May or may not include a file-extension
    var name: String

    var mimeType: String?

    /// The remote URL describing the image
    var descriptionURL: URL

    /// The remote URL of the image/video file
    var url: URL
    /// The preferred thumbURL of the image/video file
    var thumbURL: URL?

    var width: Int?
    var height: Int?

    /// filesize (byte)
    var size: Int?

    /// short structured data caption
    var captions: [LanguageString]

    /// Unlimited length html description parsed from raw wikitext
    var fullDescriptions: [LanguageString]

    var parsedWikitextDateString: String?

    /// usually something like `"<a href=\"//commons.wikimedia.org/wiki/User:SomeUsername\" title=\"User:SomeUsername\">SomeUsername</a>"`, parsed via libsoup before storage
    /// can be used for display when run first through libsoup as a fallback when structured authors not available.
    let authorRaw: String?

    /// "credit" string parsed from raw wikitext via extMetadata, should be first parsed via libsoup to extra the raw useful string at fetch/DB-insert time
    /// usually comes from API like: <span class=\"int-own-work\">Self-photographed</span>, should be "Self-photographed"
    var sourceTextRaw: String?

    // the other license values come from the imageInfo query via extmetadata:

    /// preferably used if not nil for credit line instead of author
    var attribution: String?

    var attributionRequired: Bool?
    var licenseShortName: String?
    var usageTerms: String?
    var licenseURL: URL?

    var uploadDate: Date

    var categories: [String]

    // most common properties seen here: https://commons.wikimedia.org/wiki/Commons:Structured_data/Properties_table
    var statements: [WikidataClaim]

    var fetchDate: Date

    var itemInteractionID: Int64?

    init(
        id: String,
        revid: Int? = nil,
        name: String,
        url: URL,
        descriptionURL: URL,
        thumbURL: URL? = nil,
        width: Int? = nil,
        height: Int? = nil,
        size: Int? = nil,
        uploadDate: Date,
        caption: [LanguageString],
        fullDescription: [LanguageString],
        categories: [String],
        statements: [WikidataClaim],
        mimeType: String?,
        username: String,
        fetchDate: Date,
        parsedWikitextDateString: String?,
        authorRaw: String?,
        sourceTextRaw: String?,
        licenseShortName: String?,
        usageTerms: String?,
        licenseURL: URL?
    ) {
        self.fetchDate = fetchDate
        self.name = String(name.trimmingPrefix("File:"))
        self.id = id
        self.revid = revid
        self.url = url
        self.descriptionURL = descriptionURL
        self.thumbURL = thumbURL
        self.width = width
        self.height = height
        self.size = size
        self.uploadDate = uploadDate
        self.captions = caption
        self.fullDescriptions = fullDescription
        self.categories = categories
        self.statements = statements
        self.mimeType = mimeType
        self.username = username
        self.parsedWikitextDateString = parsedWikitextDateString
        self.authorRaw = authorRaw
        self.sourceTextRaw = sourceTextRaw
        self.licenseShortName = licenseShortName
        self.usageTerms = usageTerms
        self.licenseURL = licenseURL
    }
}


// MARK: - Database

/// Make MediaFile a Codable Record.
///
/// See <https://github.com/groue/GRDB.swift/blob/master/README.md#records>
nonisolated extension MediaFile: Codable, FetchableRecord, MutablePersistableRecord {
    // Define database columns from CodingKeys
    nonisolated enum Columns {
        static let id = Column(CodingKeys.id)
        static let revid = Column(CodingKeys.revid)
        static let itemInteractionID = Column(CodingKeys.itemInteractionID)
        static let username = Column(CodingKeys.username)
        static let name = Column(CodingKeys.name)
        static let mimeType = Column(CodingKeys.mimeType)
        static let url = Column(CodingKeys.url)
        static let thumbURL = Column(CodingKeys.thumbURL)
        static let width = Column(CodingKeys.width)
        static let height = Column(CodingKeys.height)
        static let size = Column(CodingKeys.size)
        static let captions = Column(CodingKeys.captions)
        static let fullDescriptions = Column(CodingKeys.fullDescriptions)
        static let uploadDate = Column(CodingKeys.uploadDate)
        static let categories = Column(CodingKeys.categories)
        static let statements = Column(CodingKeys.statements)
    }

    // itemInteractionId foreign key
    static nonisolated let itemInteraction = belongsTo(ItemInteraction.self)

    nonisolated var itemInteraction: QueryInterfaceRequest<ItemInteraction> {
        request(for: Self.itemInteraction)
    }

}
