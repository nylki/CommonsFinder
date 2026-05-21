//
//  FileAnalysis.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 17.02.26.
//

import CoreLocation
import Foundation

@Observable final class FileAnalysis {
    enum Status: Equatable, Hashable {
        case none
        case analyzing
        case finished(ImageAnalysisResult?)

        var result: ImageAnalysisResult? {
            if case .finished(let result) = self { result } else { nil }
        }
    }

    enum Input: Equatable, Identifiable {
        case draft(MediaFileDraft)
        case mediaFile(MediaFile)
        case fileLocation(CLLocationCoordinate2D, horizontalError: CLLocationDistance?, bearing: CLLocationDegrees?)

        var id: String {
            switch self {
            case .draft(let mediaFileDraft):
                mediaFileDraft.id
            case .mediaFile(let mediaFile):
                mediaFile.id
            case .fileLocation(let coordinate, let horizontalError, let bearing):
                "\(coordinate.description) \(horizontalError ?? -1) \(bearing ?? 9999)"
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
        if let key = input?.id {
            cache[key]
        } else {
            nil
        }

    }

    func startAnalyzingIfNeeded(_ draft: MediaFileDraft) {
        startAnalyzingIfNeeded(.draft(draft))
    }

    func startAnalyzingIfNeeded(_ mediaFile: MediaFile) {
        startAnalyzingIfNeeded(.mediaFile(mediaFile))
    }

    func startAnalyzingIfNeeded(_ coordinate: CLLocationCoordinate2D, horizontalError: CLLocationDistance, bearing: CLLocationDegrees) {
        startAnalyzingIfNeeded(.fileLocation(coordinate, horizontalError: horizontalError, bearing: bearing))
    }


    func startAnalyzingIfNeeded(_ input: Input) {
        let key = input.id
        guard cache[key] == nil else { return }


        if cache.keys.count > 200 {
            cache.removeAll()
        }

        tasks[key]?.cancel()
        cache[key] = .analyzing
        tasks[key] = Task<Void, Never> {
            let result =
                switch input {
                case .draft(let draft):
                    await FileAnalysisHelpers.analyze(draft: draft, appDatabase: appDatabase)
                case .mediaFile(let mediaFile):
                    await FileAnalysisHelpers.analyze(mediaFile: mediaFile, appDatabase: appDatabase)
                case .fileLocation(let coordinate, let horizontalError, let bearing):
                    await FileAnalysisHelpers.analyze(coordinate: coordinate, horizontalError: horizontalError, bearing: bearing, appDatabase: appDatabase)
                }
            cache[key] = .finished(result)
            tasks[key] = nil
        }

    }

}
