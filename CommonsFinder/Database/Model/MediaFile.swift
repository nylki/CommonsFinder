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

struct MediaFile: Equatable, Hashable, Sendable, Identifiable {
    typealias LanguageCode = String

    ///  pageID
    var id: String

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

    var width: Double?
    var height: Double?

    /// short structured data caption
    var captions: [LanguageString]

    /// Unlimited length html description parsed from raw wikitext
    var fullDescriptions: [LanguageString]
    /// attribution string parsed from raw wikitext via extMetadata
    var rawAttribution: String?

    var uploadDate: Date

    var categories: [String]

    // most common properties seen here: https://commons.wikimedia.org/wiki/Commons:Structured_data/Properties_table
    var statements: [WikidataClaim]

    var fetchDate: Date

    init(
        id: String,
        name: String,
        url: URL,
        descriptionURL: URL,
        thumbURL: URL? = nil,
        width: Double? = nil,
        height: Double? = nil,
        uploadDate: Date,
        caption: [LanguageString],
        fullDescription: [LanguageString],
        rawAttribution: String?,
        categories: [String],
        statements: [WikidataClaim],
        mimeType: String?,
        username: String,
        fetchDate: Date
    ) {
        self.name = name
        self.fetchDate = fetchDate

        let nameRef = Reference(Substring.self)
        //        let fileEndingRef = Reference(Substring.self)

        let titleRegex = Regex {
            "File:"
            Capture(as: nameRef) {
                OneOrMore(.anyNonNewline)
            }
        }

        if let titleMatch = name.firstMatch(of: titleRegex) {
            self.name = String(titleMatch[nameRef])
        } else {
            self.name = name
        }

        self.id = id
        self.url = url
        self.descriptionURL = descriptionURL
        self.thumbURL = thumbURL
        self.width = width
        self.height = height
        self.uploadDate = uploadDate
        self.captions = caption
        self.fullDescriptions = fullDescription
        self.rawAttribution = rawAttribution
        self.categories = categories
        self.statements = statements
        self.mimeType = mimeType
        self.username = username
    }
}


// MARK: - Database

/// Make MediaFile a Codable Record.
///
/// See <https://github.com/groue/GRDB.swift/blob/master/README.md#records>
extension MediaFile: Codable, FetchableRecord, MutablePersistableRecord {
    // Define database columns from CodingKeys
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let username = Column(CodingKeys.username)
        static let name = Column(CodingKeys.name)
        static let mimeType = Column(CodingKeys.mimeType)
        static let url = Column(CodingKeys.url)
        static let thumbURL = Column(CodingKeys.thumbURL)
        static let width = Column(CodingKeys.width)
        static let height = Column(CodingKeys.height)
        static let captions = Column(CodingKeys.captions)
        static let fullDescriptions = Column(CodingKeys.fullDescriptions)
        static let uploadDate = Column(CodingKeys.uploadDate)
        static let categories = Column(CodingKeys.categories)
        static let statements = Column(CodingKeys.statements)
    }

    static let itemInteraction = hasOne(ItemInteraction.self)
    var mediaFileUsage: QueryInterfaceRequest<ItemInteraction> {
        request(for: MediaFile.itemInteraction)
    }
}

// MARK: - Extensions

extension MediaFile {

    /// The unique name *with* "File:"-prefix as used in the action-API
    var apiName: String { "File:\(name)" }

    var displayName: String {
        if let nameWithoutFileEnding = name.split(separator: ".").first {
            String(nameWithoutFileEnding)
        } else {
            name
        }
    }

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

    var licenses: [WikidataClaim] {
        statements.filter(\.isLicense)
    }

    var descriptionUrlLicenseSection: URL {
        descriptionURL.appending(component: "#Licensing")
    }

    /// If there are multiple licenses defined, pick the most relevant one for the app to display
    var primaryLicenseForDisplay: WikidataItemID? {
        // NOTE: rank does not appear to be properly used here, even though marked in commons web ui?
        if licenses.count > 1 {
            for license in licenses {
                guard let id = license.mainItem else { continue }
                if WikidataItemID.preferredLicenses.contains(id) {
                    return id
                }
            }

            for license in licenses {
                guard let id = license.mainItem else { continue }
                if WikidataItemID.acceptableLicenses.contains(id) {
                    return id
                }
            }
        }

        return licenses.first?.mainItem
    }

    var copyrightStatus: WikidataItemID? {
        if let wikidataItem = statements.first(where: \.isCopyrightStatus)?.mainItem {
            wikidataItem
        } else {
            nil
        }
    }

    var inceptionDate: Date? {
        if let statement = statements.first(where: \.isInception),
            case let .time(dateValue) = statement.mainsnak.datavalue
        {
            dateValue.date
        } else {
            nil
        }
    }

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

        guard let thumbURL = URL(string: "https://upload.wikimedia.org/wikipedia/\(base)/thumb/\(hashAndTitle)/\(maxWidth)px-\(title)") else {
            return nil
        }
        return thumbURL
    }
}
