//
//  MediaFile+InitFromAPI.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 26.10.24.
//

import CommonsAPI
import Foundation
import UniformTypeIdentifiers

extension MediaFile {
    init(apiFileMetadata: RawFileMetadata) {
        let imageInfo = apiFileMetadata.pageData.imageinfo
        let thumbURL = try? imageInfo.thumburl ?? imageInfo.url.resizedCommonsImageURL(maxWidth: 620)

        let statements: [WikidataClaim] = apiFileMetadata.structuredData.statements.values
            .flatMap { $0 }

        // TODO: get directly from api
        let mimeType = UTType(filenameExtension: imageInfo.url.pathExtension)?.preferredMIMEType

        let categories: [String] = apiFileMetadata.pageData.categories.map {
            String($0.title.split(separator: "Category:")[0])
        }

        let fullDescription: [LanguageString] =
            if let imageDescription = imageInfo.extmetadata?.imageDescription {
                imageDescription.map { (languageCode, value) in
                    LanguageString(value, languageCode: languageCode)
                }
            } else {
                []
            }

        self.init(
            id: String(apiFileMetadata.pageData.pageid),
            name: apiFileMetadata.pageData.title,
            url: imageInfo.url,
            descriptionURL: imageInfo.descriptionurl,
            thumbURL: thumbURL,
            width: imageInfo.width,
            height: imageInfo.height,
            uploadDate: imageInfo.timestamp,
            caption: apiFileMetadata.structuredData.labels.map { .init($0.value, languageCode: $0.key) },
            fullDescription: fullDescription,
            rawAttribution: apiFileMetadata.pageData.imageinfo.extmetadata?.attribution,
            categories: categories,
            statements: statements,
            mimeType: mimeType,
            username: apiFileMetadata.pageData.imageinfo.user,
            fetchDate: .now
        )
    }
}
