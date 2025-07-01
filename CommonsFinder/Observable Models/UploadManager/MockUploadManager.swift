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
@Observable @MainActor
final class MockUploadManager: UploadManager {
    enum UploadMockSimulation {
        // a couple seconds
        case regular
        case withErrors
    }

    private let uploadMockSimulation: UploadMockSimulation

    init(mockSimulation: UploadMockSimulation, appDatabase: AppDatabase) {
        self.uploadMockSimulation = mockSimulation
        super.init(appDatabase: appDatabase)
    }

    private func simulateRegularUpload(_ uploadable: MediaFileUploadable) {
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            uploadStatus[uploadable.id] = .uploading(0.01)

            try? await Task.sleep(for: .milliseconds(500))
            uploadStatus[uploadable.id] = .uploading(0.1)

            try? await Task.sleep(for: .milliseconds(500))
            uploadStatus[uploadable.id] = .uploading(0.2)

            try? await Task.sleep(for: .milliseconds(500))
            uploadStatus[uploadable.id] = .uploading(0.5)

            try? await Task.sleep(for: .milliseconds(500))
            uploadStatus[uploadable.id] = .uploading(0.8)

            try? await Task.sleep(for: .milliseconds(500))
            uploadStatus[uploadable.id] = .uploading(1)
            try? await Task.sleep(for: .milliseconds(500))
            uploadStatus[uploadable.id] = .unstashingFile

            try? await Task.sleep(for: .milliseconds(600))
            uploadStatus[uploadable.id] = .creatingWikidataClaims

            try? await Task.sleep(for: .milliseconds(600))
            uploadStatus[uploadable.id] = .published
            try? await Task.sleep(for: .milliseconds(1000))
        }
    }

    private func simulateErrorUpload(_ uploadable: MediaFileUploadable) {
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            uploadStatus[uploadable.id] = .uploading(0.01)

            try? await Task.sleep(for: .milliseconds(500))
            uploadStatus[uploadable.id] = .uploading(0.1)

            try? await Task.sleep(for: .milliseconds(1000))
            uploadStatus[uploadable.id] = .unspecifiedError("simulated uploading error")
        }
    }

    override func performUpload(_ uploadable: MediaFileUploadable) {
        switch uploadMockSimulation {
        case .regular:
            simulateRegularUpload(uploadable)
            didFinishUpload.send(uploadable.filename)
        case .withErrors:
            simulateErrorUpload(uploadable)
        }
    }
}
