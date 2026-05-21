//
//  FilenameUtils.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 13.05.26.
//

import Foundation
import UniformTypeIdentifiers

nonisolated enum FilenameUtils {
    static func generateMultiDraftFinalFilenames(multiDraftInfo: MultiDraftInfo) throws -> [MediaFileDraft.ID: String] {

        let baseName = multiDraftInfo.multiDraft.name
        var fileNumber = 1
        let digitCount = Int(floor(log10(Double(multiDraftInfo.drafts.count)) + 1))

        var resultNames: [MediaFileDraft.ID: String] = [:]

        for draft in multiDraftInfo.drafts {
            guard let uniformType = UTType(mimeType: draft.mimeType) else {
                throw UploadManagerError.missingMimetypePreventedFinalFilenameGeneration
            }

            var finalFilename =
                switch multiDraftInfo.multiDraft.nameSuffix {
                case .numberingZeroPadded:
                    baseName + ", \(String(format: "%0\(digitCount)d", fileNumber))"
                case .numbering:
                    baseName + ", \(fileNumber)"
                }
            finalFilename =
                finalFilename
                .appendingFileExtension(conformingTo: uniformType)
                .precomposedStringWithCanonicalMapping

            resultNames[draft.id] = finalFilename
            fileNumber += 1
        }

        return resultNames


    }
}
