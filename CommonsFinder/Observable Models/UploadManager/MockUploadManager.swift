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

    init(mockSimulation: UploadMockSimulation, appDatabase: AppDatabase, accountModel: AccountModel) {
        //        print("init MockUploadManager")
        self.uploadMockSimulation = mockSimulation
        super.init(appDatabase: appDatabase, accountModel: accountModel)
    }

    private func simulateRegularUpload(_ idType: DraftIDType) {

        switch idType {
        case .singleDraft(let id):
            print("simulateRegularUpload single \(id)")
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                _ = try? setPublishingState(for: id, to: .uploading(0.01))
                try? await Task.sleep(for: .milliseconds(500))
                _ = try? setPublishingState(for: id, to: .uploading(0.1))
                try? await Task.sleep(for: .milliseconds(500))
                _ = try? setPublishingState(for: id, to: .uploading(0.2))
                try? await Task.sleep(for: .milliseconds(500))
                _ = try? setPublishingState(for: id, to: .uploading(0.5))
                try? await Task.sleep(for: .milliseconds(1000))
                _ = try? setPublishingState(for: id, to: .uploading(0.8))
                try? await Task.sleep(for: .milliseconds(500))
                _ = try? setPublishingState(for: id, to: .uploading(1))
                _ = try? setPublishingState(for: id, to: .uploaded(filekey: "aaaa"))
                try? await Task.sleep(for: .milliseconds(500))
                _ = try? setPublishingState(for: id, to: .unstashingFile(filekey: "aaaa"))
                try? await Task.sleep(for: .milliseconds(600))
                _ = try? setPublishingState(for: id, to: .creatingWikidataClaims)
                try? await Task.sleep(for: .milliseconds(600))
                _ = try? setPublishingState(for: id, to: .published)
                try? await Task.sleep(for: .milliseconds(1000))
            }
        case .multiDraft(let id):
            print("simulateRegularUpload multi \(id)")
            Task {
                var state = MultiDraft.PublishingState(overallProgress: 0.00, isFinished: false, completedCount: 0, totalCount: 4)

                try? await Task.sleep(for: .milliseconds(100))
                state.overallProgress = 0.05
                try? setPublishingState(for: id, updatedState: state)

                try? await Task.sleep(for: .milliseconds(500))
                state.overallProgress = 0.1
                try? setPublishingState(for: id, updatedState: state)

                try? await Task.sleep(for: .milliseconds(500))
                state.overallProgress = 0.2
                state.completedCount = 1
                try? setPublishingState(for: id, updatedState: state)

                try? await Task.sleep(for: .milliseconds(500))
                state.overallProgress = 0.45
                state.completedCount = 2
                try? setPublishingState(for: id, updatedState: state)

                try? await Task.sleep(for: .milliseconds(1000))
                state.overallProgress = 0.652
                state.completedCount = 3
                try? setPublishingState(for: id, updatedState: state)

                try? await Task.sleep(for: .milliseconds(500))
                state.overallProgress = 1
                state.completedCount = 4
                try? setPublishingState(for: id, updatedState: state)
                try? await Task.sleep(for: .milliseconds(500))

                state.overallProgress = 1
                state.completedCount = state.totalCount
                state.isFinished = true

                try? setPublishingState(for: id, updatedState: state)

            }
        }


    }

    private func simulateErrorUpload(_ idType: DraftIDType) {
        print("simulateErrorUpload")


        switch idType {
        case .singleDraft(let id):
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                _ = try? setPublishingState(for: id, to: .uploading(0.01))

                try? await Task.sleep(for: .milliseconds(500))
                _ = try? setPublishingState(for: id, to: .uploading(0.1))

                try? await Task.sleep(for: .milliseconds(1000))
                _ = try? setPublishingError(for: id, error: .uploadWarnings([.existsNormalized(normalizedName: "Some-similar-name.jpeg")]))
            }
        case .multiDraft(let id):

            guard let uploadables = queuedMultiUploadables[idType] else { return }

            Task {

                var state = MultiDraft.PublishingState(overallProgress: 0.00, isFinished: false, completedCount: 0, totalCount: uploadables.count)

                for uploadable in uploadables {
                    try? await Task.sleep(for: .milliseconds(1000))

                    if uploadable == uploadables.last {
                        try? setPublishingState(for: uploadable.id, to: .creatingWikidataClaims)
                        try? setPublishingError(for: uploadable.id, error: .error(errorDescription: "Some simulated error", recoverySuggestion: "Some suggestion."))
                    } else {
                        try? setPublishingState(for: uploadable.id, to: .published)
                    }

                    state.overallProgress += Double(1) / Double(uploadables.count)
                    state.completedCount += 1
                    try? setPublishingState(for: id, updatedState: state)
                }

                state.overallProgress = 1
                try? setPublishingState(for: id, updatedState: state)

                try? await Task.sleep(for: .milliseconds(1000))

                state.isFinished = true
                try? setPublishingState(for: id, updatedState: state)
            }
        }
    }

    override func performUpload(_ id: DraftIDType, startStep: API.PublishingStep = .uploadData) {
        print("perform simulated upload")
        switch uploadMockSimulation {
        case .regular:
            simulateRegularUpload(id)
        case .withErrors:
            simulateErrorUpload(id)
        }
    }
}
