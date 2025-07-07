//
//  PreviewEnvironment.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 17.12.24.
//


import SwiftUI

struct PopulatedPreviewEnvironment: PreviewModifier {
    private let navigation: Navigation = .init()
    private let mockUploadManager: UploadManager
    static private let previewDatabase = AppDatabase.populatedPreviewDatabase()
    private let account: AccountModel
    private let searchModel: SearchModel

    static func makeSharedContext() async throws -> AppDatabase {
        Self.previewDatabase
    }

    init(uploadSimulation: MockUploadManager.UploadMockSimulation = .regular) {
        mockUploadManager = MockUploadManager(
            mockSimulation: uploadSimulation,
            appDatabase: Self.previewDatabase
        )

        account = AccountModel(
            appDatabase: Self.previewDatabase,
            withTestUser: .init(username: "Testuser")
        )
        searchModel = SearchModel(appDatabase: Self.previewDatabase)
    }

    func body(content: Content, context: AppDatabase) -> some View {
        content
            .appDatabase(context)
            .environment(account)
            .environment(searchModel)
            .environment(navigation)
            .environment(mockUploadManager)
    }
}

extension PreviewTrait where T == Preview.ViewTraits {
    static var previewEnvironment: PreviewTrait<T> {
        PreviewTrait(.modifier(PopulatedPreviewEnvironment()))
    }

    /// Returns full preview environment with some sample in-memory DB
    static func previewEnvironment(
        uploadSimulation: MockUploadManager.UploadMockSimulation = .regular
    ) -> PreviewTrait<T> {
        PreviewTrait(.modifier(PopulatedPreviewEnvironment(uploadSimulation: uploadSimulation)))
    }
}
