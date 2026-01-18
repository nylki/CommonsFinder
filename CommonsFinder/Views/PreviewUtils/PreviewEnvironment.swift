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
    private let mediaFileCache: MediaFileReactiveCache
    private let mapModel: MapModel

    static func makeSharedContext() async throws -> AppDatabase {
        Self.previewDatabase
    }

    init(
        uploadSimulation: MockUploadManager.UploadMockSimulation = .regular,
        prefilledSearchMedia: [MediaFileInfo] = [],
        prefilledSearchCategories: [CategoryInfo] = []
    ) {
        account = AccountModel(
            appDatabase: Self.previewDatabase,
            withTestUser: .init(username: "DebugTester")
        )

        mockUploadManager = MockUploadManager(
            mockSimulation: uploadSimulation,
            appDatabase: Self.previewDatabase,
            accountModel: account
        )

        searchModel = SearchModel(
            appDatabase: Self.previewDatabase,
            mediaResults: .init(previewAppDatabase: Self.previewDatabase, searchString: "", prefilledMedia: prefilledSearchMedia),
            categoryResults: .init(previewAppDatabase: Self.previewDatabase, searchString: "", prefilledCategories: prefilledSearchCategories)
        )
        mediaFileCache = MediaFileReactiveCache(appDatabase: Self.previewDatabase)
        mapModel = MapModel(appDatabase: Self.previewDatabase, navigation: navigation, mediaFileCache: mediaFileCache)


    }

    func body(content: Content, context: AppDatabase) -> some View {
        content
            .appDatabase(context)
            .environment(account)
            .environment(searchModel)
            .environment(navigation)
            .environment(mockUploadManager)
            .environment(mapModel)
            .environment(mediaFileCache)
    }
}

extension PreviewTrait where T == Preview.ViewTraits {
    /// Returns full preview environment with some sample in-memory DB
    static var previewEnvironment: PreviewTrait<T> {
        PreviewTrait(.modifier(PopulatedPreviewEnvironment()))
    }


    static func previewEnvironment(
        prefilledSearchMedia: [MediaFileInfo], prefilledSearchCategories: [CategoryInfo]
    ) -> PreviewTrait<T> {
        PreviewTrait(
            .modifier(
                PopulatedPreviewEnvironment(
                    prefilledSearchMedia: prefilledSearchMedia,
                    prefilledSearchCategories: prefilledSearchCategories)
            ))
    }

    static func previewEnvironment(
        uploadSimulation: MockUploadManager.UploadMockSimulation = .regular
    ) -> PreviewTrait<T> {
        PreviewTrait(.modifier(PopulatedPreviewEnvironment(uploadSimulation: uploadSimulation)))
    }
}
