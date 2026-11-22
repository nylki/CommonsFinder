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

    struct Author: Equatable, Hashable, Sendable {
        let text: String?
        let username: String?
        /// may be a link to the wikimedia user page or other link (eg. flickr)
        let url: URL?
        /// if the author has their own wikidata entry
        let wikidataID: String?
    }


    //    struct DateTimeOriginal: Equatable, Hashable, Sendable, Codable {
    //
    //        /// 11 = day
    //        /// 10 = month
    //        /// 9 = year
    //        /// 8 = decade
    //        /// 7 = century
    //        /// 6 = millenium
    //        let precision: UInt?
    //
    //        // This is directly from wikibase, which uses a weird dateTime format
    //        // for precision >=11 this can be directly used, but for other precisions
    //        // only parts of the date components (eg. only year) can be used.
    //        let wikibaseString: String?
    //
    //        let calendarWikidataID: String?
    //        let timezone: Int?
    //
    //        init(precision: UInt?, wikibaseString: String?, timezone: Int?, calendarWikidataID: String?) {
    //            self.precision = precision
    //            self.wikibaseString = wikibaseString
    //            self.timezone = timezone
    //            self.calendarWikidataID = calendarWikidataID
    //        }
    ////
    ////        var preciseDate: Date? {
    ////            if let wikibaseString, let precision, precision >= 11 {
    ////                parsedDate
    ////            } else {
    ////                nil
    ////            }
    ////        }
    //
    //        var datecomponents: DateComponents? {
    //
    //            let yearRef = Reference(Substring.self)
    //            let MonthRef = Reference(Substring.self)
    //            let dayRef = Reference(Substring.self)
    //
    //            let dateRegex = Regex {
    //                Capture(as: yearRef) {
    //                    Optionally { One(.anyOf("+-")) }
    //                    OneOrMore(.digit)
    //                }
    //                One("-")
    //                Capture(as: MonthRef) {
    //                    OneOrMore(.digit)
    //                }
    //                One("-")
    //                Capture(as: dayRef) {
    //                    OneOrMore(.digit)
    //                }
    //                One("T")
    //            }
    //
    //            if let wikibaseString, let match = wikibaseString.firstMatch(of: dateRegex) {
    //                let year = Int(match[yearRef])
    //                let month = Int(match[MonthRef])
    //                let day = Int(match[dayRef])
    //                return switch precision {
    //                case 11: .init(year: year, month: month, day: day)
    //                case 10: .init(year: year, month: month)
    //                case 9: .init(year: year)
    //                default: nil
    //            }
    //            } else {
    //                return nil
    //            }
    //        }
    //    }

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
    var dateTimeWikibase: WikiDataValueTime? {
        // TODO: take qualifiers into account (start, end, circa, etc)
        statements.filter(\.isInception).compactMap(\.mainsnak.datavalue?.timeValue).first
    }

    var structuredAuthors: [Author] {
        statements.filter(\.isCreator)
            .map { claim in
                Author(
                    text: claim.authorNameString,
                    username: claim.authorWikimediaUsernameString,
                    url: claim.authorURL,
                    wikidataID: claim.mainItem?.id
                )
            }
    }
    /// usually something like `"<a href=\"//commons.wikimedia.org/wiki/User:SomeUsername\" title=\"User:SomeUsername\">SomeUsername</a>"`, parsed via libsoup before storage
    /// can be used for display when run first through libsoup as a fallback when structured authors not available.
    let authorRaw: String?

    /// "credit" string parsed from raw wikitext via extMetadata, should be first parsed via libsoup to extra the raw useful string at fetch/DB-insert time
    /// usually comes from API like: <span class=\"int-own-work\">Self-photographed</span>, should be "Self-photographed"
    var sourceTextRaw: String?

    var licenseWikidataID: String? {
        statements.filter(\.isLicense).first?.mainItem?.id
    }
    var sourceWikidataID: String? {
        statements.filter(\.isSource).first?.mainItem?.id
    }

    // the other license values come from the imageInfo query via extmetadata:
    var licenseRaw: String?
    var licenseShortName: String?
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
        licenseRaw: String?,
        licenseShortName: String?,
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
        self.licenseRaw = licenseRaw
        self.licenseShortName = licenseShortName
        self.licenseURL = licenseURL
        self.sourceTextRaw = sourceTextRaw
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

// MARK: - Extensions

nonisolated extension MediaFile {

    var pageID: String { id }

    /// The unique name *with* "File:"-prefix as used in the action-API
    var apiName: String { "File:\(name)" }

    /// The Wikibase entity id for this file (M-prefixed page id).
    var entityId: String {
        if id.hasPrefix("M") {
            assertionFailure("the id (which directly maps to the pageid) is not expected to have the M-prefix.")
            return id
        }
        return "M\(id)"
    }

    var displayName: String {
        name.fileName()
    }

    // FIXME: flat bake coordinate and heading into file
    // with both isCoordinatesOfViewPoint and objectLocation
    var coordinate: CLLocationCoordinate2D? {
        if let statement = statements.first(where: \.isCoordinatesOfViewPoint),
            case .globecoordinate(let coordinate) = statement.mainsnak.datavalue
        {
            // TODO: check for coordinate.globe==earth?
            .init(latitude: coordinate.latitude, longitude: coordinate.longitude)
        } else {
            nil
        }
    }
    // FIXME: flat bake coordinate and heading into file
    // with both isCoordinatesOfViewPoint and objectLocation
    var heading: Double? {
        if let statement = statements.first(where: \.isCoordinatesOfViewPoint),
            let qualifier = statement.qualifiers?[.heading]?.first,
            case .quantity(let quantityValue) = qualifier.datavalue
        {
            quantityValue.amountNumber
        } else {
            nil
        }
    }


    var descriptionUrlLicenseSection: URL {
        descriptionURL.appending(component: "#Licensing")
    }

    //    var copyrightStatus: WikidataItemID? {
    //        if let wikidataItem = statements.first(where: \.isCopyrightStatus)?.mainItem {
    //            wikidataItem
    //        } else {
    //            nil
    //        }
    //    }
    //
    //    var inceptionDate: Date? {
    //        if let statement = statements.first(where: \.isInception),
    //            case .time(let dateValue) = statement.mainsnak.datavalue
    //        {
    //            dateValue.date
    //        } else {
    //            nil
    //        }
    //    }

    var aspectRatio: Double? {
        if let width, let height {
            (Double(width) / Double(height))
        } else {
            nil
        }
    }

    func resizedURL(maxWidth: UInt) -> URL? {
        // from: https://upload.wikimedia.org/wikipedia/commons/2/2c/Image_Title.jpg
        // to:   https://upload.wikimedia.org/wikipedia/commons/thumb/2/2c/Image_Title.jpg/320px-Image_Title.jpg


        guard url.absoluteString.starts(with: "https://upload.wikimedia.org/wikipedia"),
            url.pathComponents.count >= 5
        else {
            return nil
        }
        /// either "commons" or "en" or something else.
        let base = url.pathComponents[2]

        let hashA = url.pathComponents[3]
        let hashB = url.pathComponents[4]
        let title = url.pathComponents[5]
        let hashAndTitle = "\(hashA)/\(hashB)/\(title)"

        guard let resizedURL = URL(string: "https://upload.wikimedia.org/wikipedia/\(base)/thumb/\(hashAndTitle)/\(maxWidth)px-\(title)") else {
            return nil
        }
        return resizedURL
    }
}
