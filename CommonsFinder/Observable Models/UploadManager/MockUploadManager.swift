//
//  MockUploadManager.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 25.03.25.
//

import BackgroundTasks
import Combine
import CommonsAPI
import Foundation

/// Mock UploadManager for Previews and simulating slow uploading etc.
@Observable
final class MockUploadManager: UploadManager {
    enum UploadMockSimulation {
        // a couple seconds
        case regular
        case withErrors
    }

    private let uploadMockSimulation: UploadMockSimulation

    init(mockSimulation: UploadMockSimulation, appDatabase: AppDatabase) {
        //        print("init MockUploadManager")
        self.uploadMockSimulation = mockSimulation
        super.init(appDatabase: appDatabase)
    }

    private func simulateRegularUpload(_ id: MediaFileDraft.ID) {
        print("simulateRegularUpload")
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            updateUploadStatus(for: id, to: .uploading(0.01))
            try? await Task.sleep(for: .milliseconds(500))
            updateUploadStatus(for: id, to: .uploading(0.1))
            try? await Task.sleep(for: .milliseconds(500))
            updateUploadStatus(for: id, to: .uploading(0.2))
            try? await Task.sleep(for: .milliseconds(500))
            updateUploadStatus(for: id, to: .uploading(0.5))
            try? await Task.sleep(for: .milliseconds(500))
            updateUploadStatus(for: id, to: .uploading(0.8))
            try? await Task.sleep(for: .milliseconds(500))
            updateUploadStatus(for: id, to: .uploading(1))
            try? await Task.sleep(for: .milliseconds(500))
            updateUploadStatus(for: id, to: .unstashingFile)
            try? await Task.sleep(for: .milliseconds(600))
            updateUploadStatus(for: id, to: .creatingWikidataClaims)
            try? await Task.sleep(for: .milliseconds(600))
            updateUploadStatus(for: id, to: .published)
            try? await Task.sleep(for: .milliseconds(1000))
        }
    }

    private func simulateErrorUpload(_ id: MediaFileDraft.ID) {
        print("simulateErrorUpload")
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            updateUploadStatus(for: id, to: .uploading(0.01))

            try? await Task.sleep(for: .milliseconds(500))
            updateUploadStatus(for: id, to: .uploading(0.1))

            try? await Task.sleep(for: .milliseconds(1000))
            updateUploadStatus(for: id, to: .uploadWarnings([.existsNormalized(normalizedName: "Some-similar-name.jpeg")]))
        }
    }

    override func performUpload(_ id: MediaFileDraft.ID) {
        print("perform simulated upload")
        switch uploadMockSimulation {
        case .regular:
            simulateRegularUpload(id)
            didFinishUpload.send(id)
        case .withErrors:
            simulateErrorUpload(id)
        }
    }
}
