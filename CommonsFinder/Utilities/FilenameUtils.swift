//
//  FilenameUtils.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 13.05.26.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum FilenameError: Error {
    case missingMimetype
    case noBaseNameProvided
    case draftInMultiDraftWithoutIndex
    case cannotCreateRangePreviewForMultiDraftWithSingleFile
}

nonisolated enum FilenameUtils {
    static func finalFilename(for draft: MediaFileDraft, in multiDraftInfo: MultiDraftInfo?) throws -> String {

        guard !draft.name.isEmpty || multiDraftInfo != nil else {
            throw FilenameError.noBaseNameProvided
        }

        guard let uniformType = UTType(mimeType: draft.mimeType) else {
            throw FilenameError.missingMimetype
        }

        let name: String

        if !draft.name.isEmpty {
            name = draft.name
        } else if let multiDraftInfo {
            guard let index = draft.multiDraftIndex else {
                throw FilenameError.draftInMultiDraftWithoutIndex
            }
            let suffix = multiDraftInfo.multiDraft.nameSuffix.description(forIndex: index, totalFileCount: multiDraftInfo.drafts.count)
            name = multiDraftInfo.multiDraft.name + suffix
        } else {
            throw FilenameError.noBaseNameProvided
        }

        return
            name
            .appendingFileExtension(conformingTo: uniformType)
            .precomposedStringWithCanonicalMapping
    }

    static func generateMultiDraftFinalFilenames(multiDraftInfo: MultiDraftInfo) throws -> [MediaFileDraft.ID: String] {

        var resultNames: [MediaFileDraft.ID: String] = [:]

        for draft in multiDraftInfo.drafts {
            resultNames[draft.id] = try finalFilename(for: draft, in: multiDraftInfo)
        }

        return resultNames
    }


    enum FilenameRangePreviewResult {
        case identicalMimetypes(AttributedString)
        case differingMimetypes
    }

    static func finalFilenamePreviewWithRange(multiDraftInfo: MultiDraftInfo) throws -> FilenameRangePreviewResult {
        let mimeType = multiDraftInfo.drafts.first?.mimeType

        let haveAllFilesIdenticalMimetypes = multiDraftInfo.drafts.allSatisfy({ $0.mimeType == mimeType })

        if let mimeType, haveAllFilesIdenticalMimetypes {
            guard let uniformType = UTType(mimeType: mimeType) else {
                throw FilenameError.missingMimetype
            }
            let fileCount = multiDraftInfo.drafts.count
            guard fileCount >= 2 else { throw FilenameError.cannotCreateRangePreviewForMultiDraftWithSingleFile }

            let rangeSuffix = multiDraftInfo.multiDraft.nameSuffix.rangeDescription(indexRange: 0...fileCount - 1)

            var name = AttributedString(
                (multiDraftInfo.multiDraft.name + rangeSuffix).appendingFileExtension(conformingTo: uniformType)
            )

            if let range = name.range(of: rangeSuffix) {
                var coloredSuffix = AttributedString(rangeSuffix)
                coloredSuffix.foregroundColor = .accentColor
                name.replaceSubrange(range, with: coloredSuffix)
            }

            return .identicalMimetypes(name)
        } else {
            return .differingMimetypes
        }
    }
}

nonisolated extension MultiDraft.MultiFileNameSuffix {

    /// returns just the suffix number, without comma or other connection, eg: "012"
    func suffix(forIndex index: Int, totalFileCount: Int) -> String {
        let fileNumber = index + 1

        let suffix: String

        switch self {
        case .numberingZeroPadded:
            let digitCount = Int(floor(log10(Double(totalFileCount)) + 1))
            suffix = String(format: "%0\(digitCount)d", fileNumber)
        case .numbering:
            suffix = String(fileNumber)
        }

        return suffix
    }

    /// returns just range, eg. 0...12 -> "01 ... 16"
    func rangeSuffix(indexRange: ClosedRange<Int>) -> String {
        let totalFileCount = indexRange.upperBound - 1
        let startSuffix = suffix(forIndex: indexRange.lowerBound, totalFileCount: totalFileCount)
        let endSuffix = suffix(forIndex: indexRange.upperBound, totalFileCount: totalFileCount)

        return "\(startSuffix)...\(endSuffix)"
    }

    /// returns the complete suffix with comma (eg. ", 01")
    func description(forIndex index: Int, totalFileCount: Int) -> String {
        Self.suffixSeparator + suffix(forIndex: index, totalFileCount: totalFileCount)
    }

    /// returns the complete range suffix with comma (eg. ", 01...16")
    func rangeDescription(indexRange: ClosedRange<Int>) -> String {
        Self.suffixSeparator + rangeSuffix(indexRange: indexRange)
    }

    private static let suffixSeparator = ", "
}
