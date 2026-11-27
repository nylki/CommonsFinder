//
//  MediaFile+convenienceAccessors.swift
//  CommonsFinder
//
//  Created by Tom on 24.11.26.
//

import CommonsAPI
import CoreLocation
import Foundation

nonisolated extension MediaFile {

    var attributionRequiredWithFallback: Bool? {
        attributionRequired ?? self.licenseGroup?.attributionRequired
    }

    var dateTimeWikibase: WikiDataValueTime? {
        // TODO: take qualifiers into account (start, end, circa, etc)
        statements.filter(\.isInception).compactMap(\.mainsnak.datavalue?.timeValue).first
    }

    struct Author: Equatable, Hashable, Sendable {
        let text: String?
        let username: String?
        /// may be a link to the wikimedia user page or other link (eg. flickr)
        let url: URL?
        /// if the author has their own wikidata entry
        let wikidataID: String?
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

    var licenseWikidataID: String? {
        statements.filter(\.isLicense).first?.mainItem?.id
    }
    var sourceWikidataID: String? {
        statements.filter(\.isSource).first?.mainItem?.id
    }

    /// normalized license enum parsed from structured data or license shortname
    var licenseGroup: MediaFileLicenseGroup? {
        var result: MediaFileLicenseGroup? = nil

        if let licenseWikidataID {
            result = MediaFileLicenseGroup(withWikidataItem: licenseWikidataID)
        }
        if result == nil, let licenseShortName {
            result = MediaFileLicenseGroup(withLicenseShortname: licenseShortName)
        }
        return result
    }

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

    var copyrightStatus: WikidataItemID? {
        if let wikidataItem = statements.first(where: \.isCopyrightStatus)?.mainItem {
            wikidataItem
        } else {
            nil
        }
    }

    var inceptionDate: Date? {
        if let statement = statements.first(where: \.isInception),
            case .time(let dateValue) = statement.mainsnak.datavalue
        {
            dateValue.preciseDate
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

        guard let resizedURL = URL(string: "https://upload.wikimedia.org/wikipedia/\(base)/thumb/\(hashAndTitle)/\(maxWidth)px-\(title)") else {
            return nil
        }
        return resizedURL
    }
    @concurrent
    func generatePlainTextCreditLine() async -> String {
        let attributionPart: String

        if let attribution, !attribution.isEmpty {
            attributionPart = attribution
        } else if !structuredAuthors.isEmpty,
            structuredAuthors.allSatisfy({ author in
                (author.text ?? author.username) != nil
            })
        {
            attributionPart = structuredAuthors.reduce(
                "",
                { partialResult, author in
                    if let username = author.username, let authorText = author.text, username != authorText {
                        return partialResult + ", \(authorText) (\(username)"
                    } else if let someAuthorName = author.text ?? author.username {
                        return partialResult + ", \(someAuthorName)"
                    } else if let someAuthorUrl = author.url?.absoluteString {
                        return partialResult + ", \(someAuthorUrl)"
                    } else {
                        assertionFailure("we expect to have atleast username, author name/text or url (only wikidata id is insufficient here.")
                        return partialResult + "Unknown Author"
                    }
                })
        } else if let authorRaw, let attributedStringAuthor = await AttributedStringCache.shared.getCachedOrParse(stringOrHtml: authorRaw) {
            attributionPart = String(attributedStringAuthor.characters)
        } else {
            attributionPart = "Unknown Author"
        }

        let licenseURLPart: String = licenseURL?.absoluteString ?? "Unknown license"
        let urlString = url.absoluteStringWithoutQueryParams
        return "\(attributionPart) (\(urlString)), \"\(name)\", \(licenseURLPart), via Wikimedia Commons"
    }
    @concurrent
    func generateHtmlCreditLine() async -> String {
        let attributionPart: String

        if let attribution, !attribution.isEmpty {
            attributionPart = attribution
        } else if !structuredAuthors.isEmpty,
            structuredAuthors.allSatisfy({ author in
                (author.text ?? author.username) != nil
            })
        {
            attributionPart = structuredAuthors.reduce(
                "",
                { partialResult, author in
                    let authorString: String

                    if let username = author.username, let authorText = author.text, username != authorText {
                        authorString = "\(authorText) (\(username))"
                    } else if let someAuthorName = author.text ?? author.username {
                        authorString = someAuthorName
                    } else {
                        assertionFailure("we expect to have atleast username, author name/text or url (only wikidata id is insufficient here.")
                        authorString = "Unknown Author"
                    }

                    if let authorUrlString = author.url?.absoluteString {
                        return partialResult + ", <a href=\"\(authorUrlString)\">\(authorString)</a>"
                    } else {
                        return partialResult + ", \(authorString)"
                    }
                })
        } else if let authorRaw, let attributedStringAuthor = await AttributedStringCache.shared.getCachedOrParse(stringOrHtml: authorRaw) {
            attributionPart = String(attributedStringAuthor.characters)
        } else {
            attributionPart = "Unknown Author"
        }

        var result = "\(attributionPart) <a href=\"\(url.absoluteStringWithoutQueryParams)\">\(name)</a>"

        if let licenseURLString = licenseURL?.absoluteString {
            result += ", <a href=\"\(licenseURLString)\" rel=\"license\">\(licenseShortName ?? "License")</a>"
        }
        result += ", via Wikimedia Commons"

        return result
    }
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
