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
    static func finalFilename(for draft: MediaFileDraft, in multiDraft: MultiDraft?, totalFileCount: Int?, withFileExtension: Bool = true) throws -> String {

        guard !draft.name.isEmpty || multiDraft != nil else {
            throw FilenameError.noBaseNameProvided
        }

        guard let uniformType = UTType(mimeType: draft.mimeType) else {
            throw FilenameError.missingMimetype
        }

        let name: String


        if !draft.name.isEmpty {
            // if the `name` is already set on the draft, prefer it instead of using the parent-MultDraft as template.
            name = draft.name
        } else if let multiDraft, multiDraft.copiedFieldsIntoSubDrafts == false, let totalFileCount {
            // otherwise when using the multiDraft combined name
            guard let index = draft.multiDraftIndex else {
                throw FilenameError.draftInMultiDraftWithoutIndex
            }
            let suffix = multiDraft.nameSuffix.description(forIndex: index, totalFileCount: totalFileCount)
            name = multiDraft.name + suffix
        } else {
            throw FilenameError.noBaseNameProvided
        }

        return if withFileExtension {
            name
                .appendingFileExtension(conformingTo: uniformType)
                .precomposedStringWithCanonicalMapping
        } else {
            name
                .precomposedStringWithCanonicalMapping
        }


    }


    enum FilenameRangePreviewResult {
        case identicalMimetypes(AttributedString)
        case differingMimetypes
    }

    static func finalFilenamePreviewWithRange(multiDraft: MultiDraft, totalFilesCount: Int, mimeTypes: [String]) throws -> FilenameRangePreviewResult {
        let haveAllFilesIdenticalMimetypes = mimeTypes.allSatisfy({ $0 == mimeTypes.first })

        if let mimeType = mimeTypes.first, haveAllFilesIdenticalMimetypes {
            guard let uniformType = UTType(mimeType: mimeType) else {
                throw FilenameError.missingMimetype
            }
            guard totalFilesCount >= 2 else { throw FilenameError.cannotCreateRangePreviewForMultiDraftWithSingleFile }

            let rangeSuffix = multiDraft.nameSuffix.rangeDescription(indexRange: 0...totalFilesCount - 1)

            var name = AttributedString(
                (multiDraft.name + rangeSuffix).appendingFileExtension(conformingTo: uniformType)
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
