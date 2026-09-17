//
//  Maintenance.swift
//  CommonsFinder
//
//  Created by Tom on 20.08.26.
//

import Foundation
import UniformTypeIdentifiers
import os.log

actor Maintenance {

    private let sessionStartDate: Date
    private var didRunAtAppLaunch = false

    init(sessionStartDate: Date) {
        self.sessionStartDate = sessionStartDate.addingTimeInterval(-1)
    }

    func performMaintenanceAtAppLaunch(appDatabase: AppDatabase) {
        guard !didRunAtAppLaunch else {
            logger.debug("Maintenance: already ran in this session, skipping.")
            return
        }
        didRunAtAppLaunch = true

        removeUnreferencedDraftFiles(appDatabase: appDatabase)
    }

    private func removeUnreferencedDraftFiles(appDatabase: AppDatabase) {
        let fileManager = FileManager.default
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .addedToDirectoryDateKey]

        let referencedFileNames: Set<String>
        let fileURLs: [URL]
        do {
            referencedFileNames = Set(try appDatabase.fetchAllDrafts().map(\.localFileName))
            fileURLs = try fileManager.contentsOfDirectory(
                at: .documentsDirectory,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]
            )
        } catch {
            logger.error("Maintenance: failed to list drafts or Documents directory: \(error)")
            return
        }

        for url in fileURLs {
            guard !referencedFileNames.contains(url.lastPathComponent) else { continue }

            guard let fileAttributes = try? url.resourceValues(forKeys: resourceKeys),
                fileAttributes.isRegularFile == true
            else { continue }


            guard let addedDate = fileAttributes.addedToDirectoryDate else {
                logger.warning("Maintenance: skipping file without addedToDirectoryDate attributes \(url.lastPathComponent)")
                continue
            }
            guard addedDate < sessionStartDate else { continue }

            do {
                logger.info("Maintenance: removing old file without draft \(url.lastPathComponent)")
                try fileManager.removeItem(at: url)
            } catch {
                logger.warning("Maintenance: failed to remove old file without draft \(url.lastPathComponent): \(error)")
            }
        }
    }
}
