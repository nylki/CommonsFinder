//
//  UploadsView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 17.02.25.
//

import CommonsAPI
import SwiftUI
import os.log

@Observable
private final class
    PaginatableUserUploadedFiles: PaginatableMediaFiles
{
    let username: String

    @ObservationIgnored
    private var continueString: String?

    init(appDatabase: AppDatabase, username: String, fileCachingStrategy: FileCachingStrategy) async throws {
        self.username = username
        try await super.init(appDatabase: appDatabase, initialTitles: [], fileCachingStrategy: fileCachingStrategy)
    }

    override internal func
        fetchRawContinuePaginationItems() async throws -> (fileIdentifiers: CommonsAPI.FileIdentifierList, canContinue: Bool)
    {
        let result = try await Networking.shared.api.listUserImages(
            of: username,
            limit: .count(500),
            start: .now,
            end: nil,
            direction: .older,
            continueString: continueString,
        )

        let canContinue = result.continueString != nil
        continueString = result.continueString
        let titles = result.titles

        return (fileIdentifiers: .titles(titles), canContinue: canContinue)
    }
}

struct UploadsView: View {
    let username: String

    @State private var paginationModel: PaginatableUserUploadedFiles? = nil
    @Environment(\.appDatabase) private var appDatabase
    @Environment(AccountModel.self) private var account

    var isAccountUser: Bool {
        account.activeUser?.username == username
    }

    var body: some View {
        ScrollView(.vertical) {
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
                    let paginationModel = try await PaginatableUserUploadedFiles(
                        appDatabase: appDatabase,
                        username: username,
                        fileCachingStrategy: isAccountUser ? .saveAll : .replaceExisting
                    )
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
