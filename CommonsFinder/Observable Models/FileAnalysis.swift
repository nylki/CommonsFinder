//
//  FileAnalysis.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 17.02.26.
//

import Foundation
import ObservableLRUCache

@Observable final class FileAnalysis {
    enum Status: Equatable, Hashable {
        case none
        case analyzing
        case finished(ImageAnalysisResult?)

        var result: ImageAnalysisResult? {
            if case .finished(let result) = self { result } else { nil }
        }
    }

    enum Input: Equatable {
        case draft(MediaFileDraft)
        case mediaFile(MediaFile)

        var id: String {
            switch self {
            case .draft(let mediaFileDraft):
                mediaFileDraft.id
            case .mediaFile(let mediaFile):
                mediaFile.id
            }
        }
    }

    private var cache: [String: Status] = [:]

    @ObservationIgnored
    private let appDatabase: AppDatabase

    @ObservationIgnored
    private var tasks: [String: Task<Void, Never>] = [:]

    init(appDatabase: AppDatabase) {
        self.appDatabase = appDatabase
    }

    func status(for input: Input?) -> Status? {
        guard let input else { return nil }
        return switch input {
        case .draft(let mediaFileDraft):
            status(for: mediaFileDraft)
        case .mediaFile(let mediaFile):
            status(for: mediaFile)
        }
    }

    func status(for draft: MediaFileDraft) -> Status? {
        cache[draft.id]
    }

    func status(for mediaFile: MediaFile) -> Status? {
        cache[mediaFile.id]
    }


    func startAnalyzingIfNeeded(_ input: Input) {
        switch input {
        case .draft(let mediaFileDraft):
            startAnalyzingIfNeeded(mediaFileDraft)
        case .mediaFile(let mediaFile):
            startAnalyzingIfNeeded(mediaFile)
        }
    }


    func startAnalyzingIfNeeded(_ draft: MediaFileDraft) {
        guard cache[draft.id] == nil else { return }
        analyze(forKey: draft.id) { [appDatabase] in
            await FileAnalysisHelpers.analyze(draft: draft, appDatabase: appDatabase)
        }
    }


    func startAnalyzingIfNeeded(_ mediaFile: MediaFile) {
        guard cache[mediaFile.id] == nil else { return }
        analyze(forKey: mediaFile.id) { [appDatabase] in
            await FileAnalysisHelpers.analyze(mediaFile: mediaFile, appDatabase: appDatabase)
        }
    }

    private func analyze(forKey key: String, operation: @escaping () async -> ImageAnalysisResult?) {
        if cache.keys.count > 200 {
            cache.removeAll()
        }

        tasks[key]?.cancel()

        tasks[key] = Task<Void, Never> {
            cache[key] = .analyzing
            let result = await operation()
            guard !Task.isCancelled else { return }
            cache[key] = .finished(result)
            tasks[key] = nil
        }
    }
}
