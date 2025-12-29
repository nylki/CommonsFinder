//
//  MediaFileDraft+DebugDraft.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 31.05.25.
//

import Foundation
import UniformTypeIdentifiers

nonisolated extension MediaFileDraft {
    /// DEBUG ONLY value, will always be `false` in Release.
    var isDebugDraft: Bool {
        #if DEBUG
            return id.starts(with: "DEBUG-DRAFT-")
        #else
            return false
        #endif
    }

    static func makeRandomEmptyDraft(id: MediaFile.ID) -> MediaFileDraft {
        let date: Date = Date(timeIntervalSince1970: .random(in: 1..<1_576_800_000))
        return MediaFileDraft.init(
            id: "DEBUG-DRAFT-" + UUID().uuidString, addedDate: .now, name: Lorem.sentence, selectedFilenameType: .captionAndDate, nameValidationResult: nil, finalFilename: "", localFileName: "", mimeType: UTType.png.preferredMIMEType,
            captionWithDesc: [.init(languageCode: "en")], inceptionDate: date,
            timezone: "+01:00",
            locationHandling: .noLocation,
            tags: [],
            license: nil,
            author: .appUser,
            source: .own
        )
    }

    static func makeRandomDraft(
        id: MediaFile.ID,
        named: String = Lorem.sentence,
        date: Date = .init(timeIntervalSince1970: .random(in: 1..<1_576_800_000))
    ) -> MediaFileDraft {
        MediaFileDraft(
            id: "DEBUG-DRAFT-" + UUID().uuidString,
            addedDate: .now,
            name: Lorem.sentence,
            selectedFilenameType: .captionAndDate,
            nameValidationResult: nil,
            finalFilename: "",
            localFileName: "",
            mimeType: UTType.png.preferredMIMEType,
            captionWithDesc: [.init(caption: Lorem.paragraph, languageCode: "en")],
            inceptionDate: date,
            timezone: "+01:00",
            locationHandling: .exifLocation,
            tags: [
                .init(.init(commonsCategory: "Lorem Ipsum"), pickedUsages: [.category]),
                .init(.earth, pickedUsages: [.depict]),
            ],
            license: DraftMediaLicense.CC0,
            author: .appUser,
            source: .own
        )
    }
}
