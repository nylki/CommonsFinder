//
//  Uploadable+initWithDraft.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 16.02.25.
//

import Algorithms
import CommonsAPI
import CoreLocation
import CryptoKit
import Foundation
import UniformTypeIdentifiers
import os.log

extension MediaFileUploadable {
    /// when the multiDraft is present, empty fields in the draft will be filled from the multiDraft if they should be missing
    init(_ draft: MediaFileDraft, multiDraft: MultiDraft? = nil, appWikimediaUsername: String) throws(UploadManagerError) {
        guard draft.localFileURL() != nil else {
            throw UploadManagerError.fileURLMissing(id: draft.id)
        }

        let uploadFileURL = try draft.preparedUploadFileURL()

        // This will be the final filename that **cannot** be renamed later online
        // so we have to make sure it is correct and has the correct file extension.
        let finalFileName = draft.finalFilename

        guard !finalFileName.isEmpty else {
            assertionFailure("The final filename must have been generated before!")
            throw UploadManagerError.finalFilenameMissing
        }

        guard let license = draft.license ?? multiDraft?.license else {
            assertionFailure("The license must have been chosen before uploading.")
            throw UploadManagerError.licenseMissing
        }

        guard let source = draft.source ?? multiDraft?.source else {
            assertionFailure("The source must have been chosen before uploading.")
            throw UploadManagerError.sourceMissing
        }

        guard let author = draft.author ?? multiDraft?.author else {
            assertionFailure("The author must have been set before uploading.")
            throw UploadManagerError.authorMissing
        }

        let mimeType = draft.mimeType

        let locationHandling = draft.locationHandling ?? multiDraft?.locationHandling

        // see: https://commons.wikimedia.org/wiki/Template:Information
        let wikitextDate: String = draft.inceptionDate.formatted(.iso8601.year().month().day())
        let wikitextSource: String
        let wikitextAuthor: String
        let wikitextLicense: String
        let wikitextLocation: String

        // created WikidataClaims from Draft data (Structured-Data statements)
        // Date and Location have already been extracted from EXIF because it is used
        // for editing (eg. to adjust location or date)
        // The uneditable rest like exposureTime is extracted here into Wikidata Statements.

        var depictStatements: [WikidataClaim] = []
        var categories: [String] = ["Uploaded with CommonsFinder", "Mobile upload"]

        let tags: [TagItem] =
            if draft.tags.isEmpty {
                multiDraft?.tags ?? []
            } else {
                draft.tags
            }

        for tag in tags {
            lazy var wikidataItemID = tag.baseItem.wikidataItemID
            lazy var commonsCategory = tag.baseItem.commonsCategory

            if tag.pickedUsages.contains(.depict), let wikidataItemID {
                depictStatements.append(.depicts(wikidataItemID))
            }
            if tag.pickedUsages.contains(.category), let commonsCategory {
                categories.append(commonsCategory)
            }
        }
        var statements: [WikidataClaim] = depictStatements

        if let wikidataLicenseItem = license.wikidataItem {
            statements.append(.license(wikidataLicenseItem))
            // Depending on the specific license, decide what the copyright status is
            switch license {
            case .CC0_1_0:
                statements.append(.copyrightStatus(.copyrightedDedicatedToThePublicDomainByCopyrightHolder))
            case .CC_BY_4_0, .CC_BY_SA_4_0, .CC_BY_3_0, .CC_BY_SA_3_0, .CC_BY_2_5, .CC_BY_SA_2_5:
                statements.append(.copyrightStatus(.copyrighted))
            case .custom(let customWikitext):
                // skip structured data for license in this case and let other wikimedia bots do the parsing as usual
                break
            default:
                statements.append(.copyrightStatus(.copyrighted))
            }
        }

        switch source {
        case .own:
            statements.append(.source(.originalCreationByUploader))
            wikitextSource = "{{Own}}"
            wikitextLicense = "{{self|\(license.wikitext)}}"
        case .selfPhotographed:
            statements.append(.source(.originalCreationByUploader))
            wikitextSource = "{{Self-photographed}}"
            wikitextLicense = "{{self|\(license.wikitext)}}"
        case .otherSource(let string):
            if !string.isEmpty {
                if string.starts(with: "http"), let url = URL(string: string) {
                    statements.append(.source(string))
                }
                wikitextSource = "\(string)"
            } else {
                wikitextSource = "{{Source missing}}"
                // TODO: warn user
            }

            wikitextLicense = "{{\(license.wikitext)}}"
        }

        switch author {
        case .unknown:
            wikitextAuthor = "{{Unknown author}}"
        case .appUser:
            // TODO: allow customization in settings, also wikidataItem, customize the display name string (2nd param)
            let usernameURL = "https://commons.wikimedia.org/wiki/User:\(appWikimediaUsername)"
            statements.append(.creator(wikimediaUsername: appWikimediaUsername, authorNameString: appWikimediaUsername, url: usernameURL))
            wikitextAuthor = "[[User:\(appWikimediaUsername)|\(appWikimediaUsername)]]"

        case .custom(let author):
            guard !author.name.isEmpty || author.url != nil || author.wikimediaUsername?.isEmpty == false else {
                wikitextAuthor = "{{Unknown author}}"
                break
            }

            statements.append(.creator(wikimediaUsername: author.wikimediaUsername, authorNameString: author.name, url: author.url?.absoluteString))
            if let wikimediaUsername = author.wikimediaUsername {
                wikitextAuthor = "[[User:\(wikimediaUsername)|\(author.name)]]"
            } else if let url = author.url {
                wikitextAuthor = "\(author.name) (\(url))"
            } else {
                wikitextAuthor = "\(author.name)"
            }
        case .wikidataId(let wikidataItem):
            // FIXME: correct wikdatatext for wikidata author
            wikitextAuthor = "\(wikidataItem)"
            statements.append(.creator(wikidataItem))
        }
        let wikidataDate: String = draft.inceptionDate.dateOnlyWikidataCompatibleISOString
        // TODO: handle the time component (complicated) at some point
        //  TODO: add timezone when handling time component
        statements.append(.inception(wikidataDate))

        let exifData = draft.loadCachedExifData()
        let exifCoordinate = exifData?.coordinate

        switch locationHandling {
        case .exifLocation:
            if let exifData, let exifCoordinate {
                let precision =
                    if let hPositioningError = exifData.hPositioningError {
                        GeoVectorMath.degrees(fromMeters: hPositioningError, atLatitude: exifCoordinate.latitude).latitudeDegrees
                    } else {
                        // If hPositioningError is missing for some reason we assign a low precision to this coordinate
                        // TODO: this should be user-tweakable
                        0.1
                    }


                statements.append(
                    .coordinatesOfViewpoint(
                        exifCoordinate,
                        altitude: exifData.altitude ?? 0,
                        precision: precision,
                        heading: exifData.normalizedBearing
                    ))

                var locationParts: [String] = []
                locationParts.append("Location|\(exifCoordinate.latitude)|\(exifCoordinate.longitude)")
                if let heading = exifData.normalizedBearing {
                    locationParts.append("heading: \(heading)")
                }

                wikitextLocation = "{{\(locationParts.joined(separator: "|"))}}"
            } else {
                logger.warning("Exif location was selected, but no exif location in exif data found.")
                wikitextLocation = ""
            }
        case .noLocation:
            wikitextLocation = ""
        case .userDefinedLocation(let latitude, let longitude, let precision):
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let altitude = exifData?.altitude ?? 0

            statements.append(.coordinatesOfViewpoint(coordinate, altitude: altitude, precision: precision, heading: exifData?.normalizedBearing))

            var locationParts: [String] = []
            locationParts.append("Location|\(latitude)|\(longitude)")
            // still use headinf from exif even if user adjusted the coordinates, because the heading is measured independently
            // and is most likely be accurate.

            if let heading = exifData?.normalizedBearing {
                locationParts.append("heading: \(heading)")
            }
            wikitextLocation = "{{\(locationParts.joined(separator: "|"))}}"
        case .none:
            wikitextLocation = ""
        }

        // Set exif metadata to structured data that is not editable (and therefore not saved in the MediaFileDraft)
        if let exifData {

            if let exposureTime = exifData.exposureTime {
                statements.append(.exposureTime(exposureTime))
            }

            if let fNumber = exifData.fNumber {
                statements.append(.fnumber(fNumber))
            }

            if let iso = exifData.isoSpeedRatings?.first {
                statements.append(.isoSpeed(iso))
            }

            if let width = exifData.normalizedWidth {
                statements.append(.width(width))
            }

            if let height = exifData.normalizedHeight {
                statements.append(.height(height))
            }

            if let fileAttributes = try? FileManager.default.attributesOfItem(atPath: uploadFileURL.path()),
                let bytes = fileAttributes[.size] as? Int64
            {
                statements.append(.dataSize(bytes))
            }

            do {
                let sha1 = try Insecure.SHA1
                    .hash(data: Data(contentsOf: uploadFileURL))
                    .map { String(format: "%02hhx", $0) }
                    .joined()

                statements.append(.sha1Checksum(sha1))
            } catch {
                throw .failedToReadFileData
            }
        }

        statements.append(.mimeType(mimeType))

        let captionWithDesc =
            if draft.captionWithDesc.isEmpty || draft.captionWithDesc.allSatisfy({ $0.caption.isEmpty && $0.fullDescription.isEmpty }) {
                multiDraft?.captionWithDesc ?? []
            } else {
                draft.captionWithDesc
            }

        let captions: [LanguageString] = captionWithDesc.map {
            .init($0.caption, languageCode: $0.languageCode)
        }

        let nonEmptyDescriptions: [(languageCode: LanguageCode, string: String)] = captionWithDesc.compactMap {
            $0.fullDescription.isEmpty ? nil : ($0.languageCode, $0.fullDescription)
        }
        var wikitextDescriptions: String = ""

        if !nonEmptyDescriptions.isEmpty {
            let formattedWikitextDescriptions: String =
                nonEmptyDescriptions.compactMap {
                    "{{\($0.languageCode)\n|\($0.string)}}"
                }
                .joined(separator: "\n")

            wikitextDescriptions = formattedWikitextDescriptions
        }

        let wikitextCategories =
            categories
            .uniqued()
            .map { "[[Category:\($0)]]" }
            .joined(separator: "\n")

        let testUploadString = ""
        // DEBUGGING NOTE: un-comment to mark uploads as test upload, eg when testing new upload functionality
        //
        // let testUploadString = "{{test upload}}"

        let wikiText = """
            =={{int:filedesc}}==
            {{Information
            |description=\(wikitextDescriptions)
            |date={{ISOdate|\(wikitextDate)}}
            |source=\(wikitextSource)
            |author=\(wikitextAuthor)
            |permission=
            |other versions=
            }}
            \(wikitextLocation)
                        
            =={{int:license-header}}==
            \(wikitextLicense)

            \(wikitextCategories)
                    
            \(testUploadString)
            """

        self.init(
            id: draft.id,
            fileURL: uploadFileURL,
            filename: finalFileName,
            mimetype: mimeType,
            claims: statements,
            captions: captions,
            wikitext: wikiText
        )
    }
}

extension Category {
    var wikidataItemID: WikidataItemID? {
        if let wikidataId {
            WikidataItemID.Q(wikidataId)
        } else {
            nil
        }
    }
}
