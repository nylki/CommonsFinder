//
//  MediaFile+InitFromAPI.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 26.10.24.
//

import CommonsAPI
import Foundation
import UniformTypeIdentifiers

nonisolated extension MediaFile {
    static func create(with apiFileMetadata: RawFileMetadata) async -> Self {
        let imageInfo = apiFileMetadata.pageData.imageinfo
        let thumbURL = try? imageInfo.thumburl ?? imageInfo.url.resizedCommonsImageURL(maxWidth: 620)

        let statements: [WikidataClaim] = apiFileMetadata.structuredData.statements.values
            .flatMap { $0 }

        // TODO: get directly from api
        let mimeType = UTType(filenameExtension: imageInfo.url.pathExtension)?.preferredMIMEType

        let categories: [String] = apiFileMetadata.pageData.categories.map {
            String($0.title.trimmingPrefix("Category:"))
        }

        let fullDescription: [LanguageString] =
            if let imageDescription = imageInfo.extmetadata?.imageDescription {
                imageDescription.map { (languageCode, value) in
                    LanguageString(value, languageCode: languageCode)
                }
            } else {
                []
            }

        var parsedWikitextDateString: String?
        if let rawDate = apiFileMetadata.pageData.imageinfo.extmetadata?.dateTimeOriginal,
            let attributedString = await AttributedStringCache.shared.getCachedOrParse(stringOrHtml: rawDate)
        {
            parsedWikitextDateString = String(attributedString.characters)
        }

        return .init(
            id: String(apiFileMetadata.pageData.pageid),
            revid: apiFileMetadata.pageData.lastrevid,
            name: apiFileMetadata.pageData.title,
            url: imageInfo.url,
            descriptionURL: imageInfo.descriptionurl,
            thumbURL: thumbURL,
            width: imageInfo.width,
            height: imageInfo.height,
            size: imageInfo.size,
            uploadDate: imageInfo.timestamp,
            caption: apiFileMetadata.structuredData.labels.map { .init($0.value, languageCode: $0.key) },
            fullDescription: fullDescription,
            categories: categories,
            statements: statements,
            mimeType: mimeType,
            username: apiFileMetadata.pageData.imageinfo.user,
            fetchDate: .now,
            
            
            
            
            
            // FIXME: parse the hidden wikidata statement returned via extmetadata to show relative dates! (eg between 1901 and 1903)
            // this can be then also used to render such statements via the statements inception date with qualifiers..
            // !!!!! BEFORE MERGING TO TESTFLIGHT !!!!!!
            
            
            
            
            parsedWikitextDateString: parsedWikitextDateString,
            authorRaw: apiFileMetadata.pageData.imageinfo.extmetadata?.artist,
            sourceTextRaw: apiFileMetadata.pageData.imageinfo.extmetadata?.credit,
            licenseRaw: apiFileMetadata.pageData.imageinfo.extmetadata?.license,
            licenseShortName: apiFileMetadata.pageData.imageinfo.extmetadata?.licenseShortName,
            licenseURL: apiFileMetadata.pageData.imageinfo.extmetadata?.licenseUrl
        )
    }
}
