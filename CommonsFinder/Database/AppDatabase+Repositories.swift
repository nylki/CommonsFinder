//
//  AppDatabase+App.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 04.10.24.
//

import Foundation
import GRDB
import os.log

// A `Database` extension for creating various repositories for the
// app, tests, and previews.
extension AppDatabase {
    /// The on-disk repository for the application.
    static let shared = makeShared()

    /// Returns an on-disk repository for the application.
    private static func makeShared() -> AppDatabase {
        do {
            // Apply recommendations from
            // <https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseconnections>
            //
            // Create the "Application Support/Database" directory if needed
            let fileManager = FileManager.default
            let appSupportURL = try fileManager.url(
                for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true)
            let directoryURL = appSupportURL.appendingPathComponent("Database", isDirectory: true)
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

            // Open or create the database
            let databaseURL = directoryURL.appendingPathComponent("db.sqlite")
            NSLog("Database stored at \(databaseURL.path)")
            let dbPool = try DatabasePool(
                path: databaseURL.path,
                // Use default AppDatabase configuration
                configuration: AppDatabase.makeConfiguration()
            )

            // Create the AppDatabase
            let appDatabase = try AppDatabase(dbPool)

            return appDatabase
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate.
            //
            // Typical reasons for an error here include:
            // * The parent directory cannot be created, or disallows writing.
            // * The database is not accessible, due to permissions or data protection when the device is locked.
            // * The device is out of space.
            // * The database could not be migrated to its latest schema version.
            // Check the error message to determine what the actual problem was.
            fatalError("Unresolved error \(error)")
        }
    }

    /// Returns an empty in-memory repository, for previews and tests.
    static func empty() -> AppDatabase {
        // Connect to an in-memory database
        // See https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databaseconnections
        let dbQueue = try! DatabaseQueue(configuration: AppDatabase.makeConfiguration())
        return try! AppDatabase(dbQueue)
    }

    static let sampleDraft: MediaFileDraft = MediaFileDraft.makeRandomDraft(id: "draftID-1")
    static let uploadableSampleDraft: MediaFileDraft = MediaFileDraft.makeRandomDraft(id: "draftID-uploadable-2", uploadPossibleStatus: .uploadPossible)
    /// Returns an in-memory repository that contains one draft and one uploaded media file,
    /// for previews and tests.
    ///
    /// - parameter fileID: The ID of the inserted media file.
    static func populatedPreviewDatabase() -> AppDatabase {
        let repo = self.empty()
        do {
            _ = try repo.upsert(sampleDraft)
            _ = try repo.insert(MediaFile.makeRandomUploaded(id: "uploadedID-1", .squareImage))
            _ = try repo.insert(MediaFile.makeRandomUploaded(id: "uploadedID-2", .verticalImage))
            _ = try repo.insert(MediaFile.makeRandomUploaded(id: "uploadedID-3", .squareImage))
            _ = try repo.insert(MediaFile.makeRandomUploaded(id: "uploadedID-4", .verticalImage))
            _ = try repo.insert(MediaFile.makeRandomUploaded(id: "uploadedID-5", .horizontalImage))
            _ = try repo.insert(MediaFile.makeRandomUploaded(id: "uploadedID-6", .horizontalImage))
            _ = try repo.insert(MediaFile.makeRandomUploaded(id: "uploadedID-7", .horizontalImage))
            _ = try repo.insert(MediaFile.makeRandomUploaded(id: "uploadedID-8", .horizontalImage))
            _ = try repo.insert(MediaFile.makeRandomUploaded(id: "uploadedID-9", .verticalImage))
            _ = try repo.insert(MediaFile.makeRandomUploaded(id: "uploadedID-10", .verticalImage))
            _ = try repo.insert(MediaFile.makeRandomUploaded(id: "uploadedID-11", .horizontalImage))

            let anImage = try repo.insert(MediaFile.makeRandomUploaded(id: "uploadedID-12", .verticalImage))
            _ = try repo.updateLastViewed(.init(mediaFile: anImage))

            let someImage = try repo.insert(MediaFile.makeRandomUploaded(id: "uploadedID-13", .squareImage))
            let someImageInfo = try repo.updateLastViewed(.init(mediaFile: someImage))
            _ = try repo.updateBookmark(someImageInfo, bookmark: true)

            let earthCat = try repo.upsert(.earth)!
            let earthCatInfo = try repo.updateLastViewed(.init(earthCat), incrementViewCount: true)
            _ = try repo.updateBookmark(earthCatInfo, bookmark: true)

        } catch {
            logger.error("Failed to populate preview DB \(error)")
            assertionFailure()
        }

        return repo
    }

    /// Returns an in-memory repository that contains one draft media file,
    /// for previews and tests.
    ///
    /// - parameter fileID: The ID of the inserted media file.
    static func populatedDraft(fileID: MediaFile.ID) -> AppDatabase {
        let repo = self.empty()
        _ = try! repo.upsert(MediaFileDraft.makeRandomDraft(id: fileID))
        return repo
    }

    /// Returns an in-memory repository that contains one uploaded media file,
    /// for previews and tests.
    ///
    /// - parameter fileID: The ID of the inserted media file.
    static func populatedUploaded(fileID: MediaFile.ID) -> AppDatabase {
        let repo = self.empty()
        _ = try! repo.insert(MediaFile.makeRandomUploaded(id: fileID, .squareImage))
        return repo
    }
}
