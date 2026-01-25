//
//  WikidataCache.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 27.10.25.
//


//
//  WikidataCache.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 26.10.24.
//

import Algorithms
import CommonsAPI
import Foundation
import GRDB
import SwiftUI
import os.log

/// This cache will fetch media files info on-demand when a non-existent key is being queried
/// This is useful for interactive SwiftUI use-cases.
@Observable final class MediaFileReactiveCache {

    /// NOTE: LRU-Cache is not observable, so just a basic dictionary here
    private var dictionary: [MediaFileInfo.ID: MediaFileInfo] = [:]

    @ObservationIgnored
    private var task: Task<Void, Error>?
    @ObservationIgnored
    private var observationTask: Task<Void, Never>?

    /// IDs that were tried to access in the subscript but could not be found will be collected here for the debounce duration
    @ObservationIgnored
    private var missingIDs: Set<MediaFileInfo.ID> = []

    @ObservationIgnored
    private let appDatabase: AppDatabase

    init(appDatabase: AppDatabase) {
        self.appDatabase = appDatabase

    }

    private func observeDatabase() {

        observationTask?.cancel()
        observationTask = Task<Void, Never> {
            do {
                let ids = Array(dictionary.keys)

                let observation = ValueObservation.tracking { db in
                    try MediaFileInfo.fetchAll(ids: ids, db: db)
                }

                for try await mediaFilesFromDB in observation.values(in: appDatabase.reader) {
                    try Task.checkCancellation()

                    mediaFilesFromDB.forEach {
                        dictionary[$0.id] = $0
                    }
                }
            } catch {
                logger.error("Failed to observe media files \(error)")
            }
        }
    }

    /// tries to retrieve item from DB and caches it into memory if found for faster access next time
    private func retrieveFromDB(id: MediaFileInfo.ID) -> MediaFileInfo? {
        let item = try? appDatabase.fetchMediaFileInfo(id: id)

        guard let item else { return nil }
        dictionary[item.id] = item
        return item
    }


    subscript(id: MediaFileInfo.ID) -> MediaFileInfo? {
        let entry = dictionary[id] ?? retrieveFromDB(id: id)

        guard let entry else {
            missingIDs.insert(id)
            fetchMissing()
            return nil
        }

        return entry
    }

    func cache(_ mediaFileInfo: MediaFileInfo) {
        dictionary[mediaFileInfo.id] = mediaFileInfo
    }

    private func fetchMissing() {
        task?.cancel()
        task = Task<Void, Error> {
            try await Task.sleep(for: .milliseconds(50))
            try Task.checkCancellation()

            let chunkedIDs = missingIDs.chunks(ofCount: 50)
            // TODO: parallelize with taskGroup?
            // NOTE: limit is 50
            for ids in chunkedIDs {
                do {
                    let apiItems = try await Networking.shared.api.fetchFullFileMetadata(.pageids(Array(ids)))
                    let fetchedMediaFiles: [MediaFile] = apiItems.map(MediaFile.init)

                    for mediaFile in fetchedMediaFiles {
                        dictionary[mediaFile.id] = .init(mediaFile: mediaFile)
                        missingIDs.remove(mediaFile.id)
                    }

                    logger.info("Fetched media files in reactive \(self.missingIDs)")

                } catch is CancellationError {

                } catch {
                    logger.error("Failed to media files in reactive cache for \(self.missingIDs) \(error)")
                }
            }

            //            observeDatabase()

        }
    }
}
