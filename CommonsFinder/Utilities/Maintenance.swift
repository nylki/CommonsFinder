//
//  Maintenance.swift
//  CommonsFinder
//
//  Created by Tom on 24.08.26.
//


//
//  Maintenance.swift
//  CommonsFinder
//
//  Created by Tom on 20.08.26.
//

import Foundation
import os.log

actor Maintenance {
    static let shared: Maintenance = .init()
    
    private var task: Task<Date, Never>?
    
    
    func performMaintenance(appDatabase: AppDatabase) async -> Date {
        
        if let task {
            logger.debug("Maintenance: task already started, awaiting result...")
            let value = await task.value
            logger.debug("Maintenance: value from already started: \(value)")
            return value
        }
        
        let newTask = Task {
            logger.debug("Maintenance: started maintenance task. awaiting result.")
            // FIXME XXX DEBUG: remove timer
            try? await Task.sleep(for: .seconds(15))
            cleanupUnusedFiles(appDatabase: appDatabase)
            return Date.now
            
        }
        
        task = newTask
        
        let value = await newTask.value
        logger.debug("Maintenance: value: \(value)")
        return value
    }
    
    
    private func cleanupUnusedFiles(appDatabase: AppDatabase) {
        let filemanager = FileManager.default
        
        let documentsDirectory: [URL]
        let existingFileURLs: Set<String>
        
        
        do {
            existingFileURLs = try appDatabase.fetchAllDraftFilenames()
            documentsDirectory = try filemanager.contentsOfDirectory(
                at: .documentsDirectory,
                includingPropertiesForKeys: nil
            )
        } catch {
            logger.error("Failed to cleanup unused files")
            return
        }
        
        let fileURLsToRemove = documentsDirectory.filter { !existingFileURLs.contains($0.lastPathComponent) }
        

        for url in fileURLsToRemove {
            do {
                logger.info("Maintenance: Removing unused file \(url.absoluteString)")
                try filemanager.removeItem(at: url)
            } catch {
                logger.warning("Maintenance: Failed to remove dangling file \(error)")
            }
            
        }
    }
    

    
}
