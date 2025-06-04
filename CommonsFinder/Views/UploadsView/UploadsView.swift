//
//  UploadsView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 17.02.25.
//

import CommonsAPI
import SwiftUI
import os.log

@Observable @MainActor
private final class
    PaginatableUserUploadedFiles: PaginatableMediaFiles
{
    let username: String

    @ObservationIgnored
    private var continueString: String?

    init(appDatabase: AppDatabase, username: String) async throws {
        self.username = username
        try await super.init(appDatabase: appDatabase)
    }

    override internal func
        fetchRawContinuePaginationItems() async throws -> (items: [String], reachedEnd: Bool)
    {
        let result = try await CommonsAPI.API.shared.listUserImages(
            of: username,
            limit: .count(500),
            start: .now,
            end: nil,
            direction: .older,
            continueString: continueString
        )

        let canContinue = result.continueString != nil
        self.continueString = result.continueString
        return (result.files.map(\.title), canContinue)
    }
}

struct UploadsView: View {
    let username: String

    @State private var paginationModel: PaginatableUserUploadedFiles? = nil
    @Environment(\.appDatabase) private var appDatabase

    var body: some View {
        ZStack {
            if let paginationModel {
                PaginatableMediaList(
                    items: paginationModel.mediaFileInfos,
                    status: paginationModel.status,
                    paginationRequest: paginationModel.paginate
                )
            }
        }
        .navigationTitle("Uploads by \(username)")
        .toolbarTitleDisplayMode(.inline)
        .task {
            if paginationModel == nil {
                do {
                    let paginationModel = try await PaginatableUserUploadedFiles(appDatabase: appDatabase, username: username)
                    self.paginationModel = paginationModel
                } catch {
                    logger.error("Error loading category images: \(error)")
                }
            }
        }
    }

}

#Preview {
    UploadsView(username: "CommonExploerTester")
}
