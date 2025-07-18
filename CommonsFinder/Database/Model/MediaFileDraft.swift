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


struct MediaFileDraft: Identifiable, Equatable, Codable, Hashable {
    // UUID-string
    let id: String

    var addedDate: Date

    var exifData: ExifData?

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

    /// The custom publication or creation date of the file to be used **instead of the EXIF-Date**
    var inceptionDate: Date
    var timezone: String?

    var locationHandling: LocationHandling

    var locationEnabled: Bool {
        get { locationHandling == .exifLocation }
        set { locationHandling = newValue ? .exifLocation : .noLocation }
    }

    var coordinate: CLLocationCoordinate2D? {
        switch locationHandling {
        case .noLocation:
            nil
        case .exifLocation:
            exifData?.location?.coordinate
        case .userDefinedLocation(let latitude, let longitude):
            .init(latitude: latitude, longitude: longitude)
        }
    }

    enum LocationHandling: Codable, Equatable, Hashable {
        /// location data will be removed from EXIF if it exists inside the binary and won't be added to wikitext or structured data
        case noLocation
        /// location data from EXIF will be used for wikitext and structured data
        case exifLocation
        /// user defined location data will be used for wikitext and structured data, EXIF-location will be overwritten by user defined location
        case userDefinedLocation(latitude: Double, longitude: Double)
    }

    var tags: [TagItem]

    var license: DraftMediaLicense?
    var author: DraftAuthor
    var source: DraftSource

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
/// See <https://github.com/groue/GRDB.swift/blob/master/README.md#records>
extension MediaFileDraft: FetchableRecord, MutablePersistableRecord {
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
}

// MARK: - Extensions

extension MediaFileDraft {
    /// Returns the location of the local file (of the image, video, etc.) if it exists
    /// This should always exist for drafts, but is not guaranteed for uploaded files.
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
    //    var coordinate: CLLocationCoordinate2D? {
    //        get {
    //            if let latitude, let longitude {
    //                CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    //            } else {
    //                nil
    //            }
    //        }
    //        set {
    //            gpsTimestamp = nil
    //        }
    //    }
    //
    //    var location: CLLocation? {
    //        if let coordinate, let altitude, let horizontalAccuracy, let gpsTimestamp {
    //            CLLocation(
    //                coordinate: coordinate,
    //                altitude: altitude,
    //                horizontalAccuracy: horizontalAccuracy,
    //                verticalAccuracy: horizontalAccuracy,
    //                timestamp: gpsTimestamp
    //            )
    //        } else if let coordinate {
    //            CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
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

        // Read EXIF-Data and insert it into MediaFileDraft entity if not previously done
        if let exifData = try? ExifData(url: fileItem.fileURL) {
            self.exifData = exifData
            locationHandling = .exifLocation

            if let date = exifData.dateOriginal {
                inceptionDate = date
            } else {
                inceptionDate = .now
            }

            if let exifTimezone = exifData.offsetTime {
                // TODO: Properly handle timezone parsing
                //                timezone = TimeZone(secondsFromGMT: .....)
                timezone = exifTimezone
            }

            // FIXME: width/hight are reversed for portrait photos due to orientation not taken into account
            // see: https://github.com/nylki/CommonsFinder/issues/5
            width = exifData.pixelWidth
            height = exifData.pixelHeight

        } else {
            locationHandling = .noLocation
            inceptionDate = .now
            timezone = TimeZone.current.identifier
        }
    }
}
