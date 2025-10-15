//
//  MediaFileDraft.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 21.01.25.
//

import CommonsAPI
import CoreGraphics
import CoreLocation
import Foundation
import GRDB
import RegexBuilder
import UniformTypeIdentifiers
import os.log

// The draft is structurally similar to the MediaFile,
// but having it as separate type gives us more flexibilty and
// make future adjustments and migrations less of a headache hopefully.
// One difference is that it stores the data suited for initial creation
// avoiding duplicates with wikidata structured data (eg. for location, date etc.)


nonisolated
struct MediaFileDraft: Identifiable, Equatable, Hashable {
    // UUID-string
    let id: String

    var addedDate: Date

    /// The unique name without the mediawiki "File:"-prefix and (should be without) any file-extension like .jpeg, editable in UI (eg. "screenshot 2025-01-01")
    var name: String
    /// `name` + file-extension is written just before uploading (eg. "screenshot 2025-01-01.jpeg")
    ///  and can be used for identifying uploaded media and local drafts
    var finalFilename: String

    /// The filename, If the represented media file exists locally on disk
    /// May be identical to "name", but not guaranteed (eg. drafts)
    var localFileName: String
    var mimeType: String?

    var captionWithDesc: [DraftCaptionWithDescription]

    /// falls back to the EXIF-data if no custom date set
    var inceptionDate: Date
    var timezone: String?

    var locationHandling: LocationHandling?

    var locationEnabled: Bool {
        get { locationHandling == .exifLocation }
        set { locationHandling = newValue ? .exifLocation : .noLocation }
    }

    enum LocationHandling: Codable, Equatable, Hashable {
        /// location data will be removed from EXIF if it exists inside the binary and won't be added to wikitext or structured data
        case noLocation
        /// location data from EXIF will be used for wikitext and structured data
        case exifLocation
        /// user defined location data will be used for wikitext and structured data, EXIF-location will be overwritten by user defined location
        case userDefinedLocation(latitude: CLLocationDegrees, longitude: CLLocationDegrees, precision: CLLocationDegrees)
    }

    var tags: [TagItem]

    var license: DraftMediaLicense?
    var author: DraftAuthor?
    var source: DraftSource?

    var width: Int?
    var height: Int?

    struct DraftCaptionWithDescription: Codable, Equatable, Hashable {
        var languageCode: LanguageCode
        var caption: String
        var fullDescription: String
    }

    enum DraftAuthor: Codable, Equatable, Hashable {
        case appUser
        case custom(name: String, wikimediaUsername: String?, url: URL?)
        case wikidataId(wikidataItem: WikidataItemID)
    }

    enum DraftSource: Codable, Equatable, Hashable {
        // see: https://commons.wikimedia.org/wiki/Commons:Structured_data/Modeling/Source
        // "Wikidata: *\(id)*"P7482

        case own
        case fileFromTheWeb(URL)
        // TODO: check correct modelling
        case book(WikidataItemID, page: Int)
    }
}

nonisolated
extension MediaFileDraft {
    /// exifData is created lazily and is not saved into the DB
    nonisolated func loadExifData() -> ExifData? {
        if let url = self.localFileURL() {
            try? ExifData(url: url)
        } else {
            nil
        }
    }
}

extension MediaFileDraft.DraftCaptionWithDescription {
    init(languageCode: LanguageCode) {
        self.languageCode = languageCode
        caption = ""
        fullDescription = ""
    }

    init(caption: String = "", fullDescription: String = "", languageCode: LanguageCode) {
        self.caption = caption
        self.fullDescription = fullDescription
        self.languageCode = languageCode
    }
}


// MARK: - Database

/// Make MediaFileDraft a Codable Record.
///
///
///
/// See <https://github.com/groue/GRDB.swift/blob/master/README.md#records>
///
nonisolated
extension MediaFileDraft: Codable, FetchableRecord, MutablePersistableRecord {
    enum CodingKeys: CodingKey {
        case id
        case addedDate
        case name
        case finalFilename
        case localFileName
        case mimeType
        case captionWithDesc
        case inceptionDate
        case timezone
        case locationHandling
        case tags
        case license
        case author
        case source
        case width
        case height
    }
    
    // Define database columns from CodingKeys
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let addedDate = Column(CodingKeys.addedDate)
        static let name = Column(CodingKeys.name)
        static let finalFilename = Column(CodingKeys.finalFilename)

        static let captionWithDesc = Column(CodingKeys.captionWithDesc)
        static let tags = Column(CodingKeys.tags)
        static let inceptionDate = Column(CodingKeys.inceptionDate)

        static let width = Column(CodingKeys.width)
        static let height = Column(CodingKeys.height)

        static let license = Column(CodingKeys.license)
        static let author = Column(CodingKeys.author)
        static let source = Column(CodingKeys.source)
    }
    

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.addedDate = try container.decode(Date.self, forKey: .addedDate)
        self.name = try container.decode(String.self, forKey: .name)
        self.finalFilename = try container.decode(String.self, forKey: .finalFilename)
        self.localFileName = try container.decode(String.self, forKey: .localFileName)
        self.mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
        self.captionWithDesc = try container.decode([MediaFileDraft.DraftCaptionWithDescription].self, forKey: .captionWithDesc)
        self.inceptionDate = try container.decode(Date.self, forKey: .inceptionDate)
        self.timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
        self.locationHandling = try container.decodeIfPresent(MediaFileDraft.LocationHandling.self, forKey: .locationHandling)
        self.license = try container.decodeIfPresent(DraftMediaLicense.self, forKey: .license)
        self.author = try container.decodeIfPresent(MediaFileDraft.DraftAuthor.self, forKey: .author)
        self.source = try container.decodeIfPresent(MediaFileDraft.DraftSource.self, forKey: .source)
        self.width = try container.decodeIfPresent(Int.self, forKey: .width)
        self.height = try container.decodeIfPresent(Int.self, forKey: .height)

        if let tags = try? container.decode([TagItem].self, forKey: .tags) {
            self.tags = tags
        } else {
            self.tags = []
        }

    }
}


// MARK: - Extensions

nonisolated extension MediaFileDraft {
    /// Returns the location of the local file (of the image, video, etc.)
    func localFileURL() -> URL? {
        URL.documentsDirectory.appending(path: localFileName)
    }

    var displayName: String {
        if let nameWithoutFileEnding = name.split(separator: ".").first {
            String(nameWithoutFileEnding)
        } else {
            name
        }
    }

    var canUpload: Bool {
        !name.isEmpty && !captionWithDesc.isEmpty && license != nil && !tags.isEmpty
    }
}

extension MediaFileDraft {
    var aspectRatio: Double? {
        if let width, let height {
            (Double(width) / Double(height))
        } else {
            nil
        }
    }
}

// MARK: - Constructors
extension MediaFileDraft {

    /// creates a new draft from an FileItem by reading its EXIF-Data filling the fields as complete as possible at this stage
    init(_ fileItem: FileItem) {
        id = UUID().uuidString
        addedDate = .now
        localFileName = fileItem.localFileName
        finalFilename = ""
        name = localFileName

        let languageCode = Locale.current.wikiLanguageCodeIdentifier
        captionWithDesc = [.init(languageCode: languageCode)]

        tags = []
        license = nil
        author = .appUser
        source = .own

        if let mimeType = fileItem.fileType.preferredMIMEType {
            self.mimeType = mimeType
        } else {
            assertionFailure("We expect the file to have a mime type")
        }

        locationHandling = .noLocation
        inceptionDate = .now
        timezone = TimeZone.current.identifier

        // Read EXIF-Data and update relevant values
        if let exifData = loadExifData() {
            locationHandling = .exifLocation

            if let date = exifData.dateOriginal {
                inceptionDate = date
            }

            if let exifTimezone = exifData.offsetTime {
                // TODO: Properly handle timezone parsing
                //                timezone = TimeZone(secondsFromGMT: .....)
                timezone = exifTimezone
            }

            width = exifData.normalizedWidth
            height = exifData.normalizedHeight

        }
    }
}
