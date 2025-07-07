//
//  FileNameType+generate.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 28.12.24.
//

import CommonsAPI
import CoreLocation
import Foundation
import os.log

extension FileNameType {
    @MainActor
    func generateFilename(
        location: CLLocation?, date: Date?, desc: [MediaFileDraft.DraftCaptionWithDescription], locale: Locale, tags: [TagItem]
    ) async
        -> String?
    {
        return switch self {
        case .custom:
            nil
        case .captionOnly:
            generateCaptionFilename(desc: desc, locale: locale)
        case .captionAndDate:
            generateCaptionAndDateFilename(desc: desc, date: date, locale: locale)
        case .geoAndDate:
            await generateGeoAndDateFilename(date: date, location: location, locale: locale)
        }
    }
}


private func generateCaptionFilename(desc: [MediaFileDraft.DraftCaptionWithDescription], locale: Locale) -> String {

    // For caption only we select the caption matching the current locales language code if it exists
    // otherwise just the first available caption.
    if let localeLanguageCode = locale.language.languageCode?.identifier,
        let localeCaption = desc.first(where: { $0.languageCode == localeLanguageCode })?.caption
    {
        return localeCaption
    } else {
        return desc.first { !$0.caption.isEmpty }?.caption ?? ""
    }
}

private func generateCaptionAndDateFilename(desc: [MediaFileDraft.DraftCaptionWithDescription], date: Date?, locale: Locale) -> String {
    let caption = generateCaptionFilename(desc: desc, locale: locale)

    let date = date?.ISO8601Format(.iso8601.year().month().day()) ?? ""

    return [caption, date].joined(separator: ", ")
}


private func generateGeoAndDateFilename(date: Date?, location: CLLocation?, locale: Locale) async -> String {
    var geoString: String?
    if let location {
        do {
            geoString = try await location.generateHumanReadableString(includeCountry: false)
        } catch {
            logger.warning("Failed to reverse geo location")
        }
    }

    let date = date?.ISO8601Format(.iso8601.year().month().day()) ?? ""

    return [geoString, date].compactMap { $0 }.joined(separator: ", ")
}
