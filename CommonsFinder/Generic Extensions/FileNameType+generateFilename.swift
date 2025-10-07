//
//  FileNameType+generate.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 28.12.24.
//

import CoreLocation
import Foundation
@preconcurrency import MapKit
import os.log

nonisolated extension FileNameType {
    func generateFilename(
        coordinate: CLLocationCoordinate2D?, date: Date?, desc: [MediaFileDraft.DraftCaptionWithDescription], locale: Locale, tags: [TagItem]
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
            await generateGeoAndDateFilename(date: date, coordinate: coordinate, locale: locale)
        }
    }
}


nonisolated private func generateCaptionFilename(desc: [MediaFileDraft.DraftCaptionWithDescription], locale: Locale) -> String {

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

nonisolated private func generateCaptionAndDateFilename(desc: [MediaFileDraft.DraftCaptionWithDescription], date: Date?, locale: Locale) -> String {
    let caption = generateCaptionFilename(desc: desc, locale: locale)

    let date = date?.ISO8601Format(.iso8601.year().month().day()) ?? ""

    return [caption, date].joined(separator: ", ")
}


nonisolated
    private func generateGeoAndDateFilename(date: Date?, coordinate: CLLocationCoordinate2D?, locale: Locale) async -> String
{
    var geoString: String?
    if let coordinate {
        let location = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        do {
            geoString = try await coordinate.generateHumanReadableString()
        } catch {
            logger.warning("Failed to reverse geo location")
        }
    }

    let date = date?.ISO8601Format(.iso8601.year().month().day()) ?? ""

    return [geoString, date].compactMap { $0 }.joined(separator: ", ")
}
