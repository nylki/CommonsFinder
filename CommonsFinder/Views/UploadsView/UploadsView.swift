//
//  UploadsView.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 17.02.25.
//

import CommonsAPI
import SwiftUI
import os.log

enum UserUploadsOrder: Equatable, CustomLocalizedStringResourceConvertible, Hashable {
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .newer: "Newer"
        case .older: "Older"
        }
    }

    case newer
    case older
}

@Observable
private final class
    PaginatableUserUploadedFiles: PaginatableMediaFiles
{
    let username: String

    private let order: UserUploadsOrder

    @ObservationIgnored
    private var continueString: String?

    init(appDatabase: AppDatabase, username: String, order: UserUploadsOrder, fileCachingStrategy: FileCachingStrategy) async throws {
        self.username = username
        self.order = order
        try await super.init(appDatabase: appDatabase, initialTitles: [], fileCachingStrategy: fileCachingStrategy)
    }

    override internal func
        fetchRawContinuePaginationItems() async throws -> (fileIdentifiers: CommonsAPI.FileIdentifierList, canContinue: Bool)
    {
        let result =
            switch order {
            case .newer:
                try await Networking.shared.api.listUserImages(
                    of: username,
                    limit: .count(500),
                    start: .now,
                    end: nil,
                    direction: .older,
                    continueString: continueString,
                )
            case .older:
                try await Networking.shared.api.listUserImages(
                    of: username,
                    limit: .count(500),
                    start: nil,
                    end: .now,
                    direction: .newer,
                    continueString: continueString,
                )
            }

        let canContinue = result.continueString != nil
        continueString = result.continueString
        let titles = result.titles

        return (fileIdentifiers: .titles(titles), canContinue: canContinue)
    }
}

struct UploadsView: View {
    let username: String

    @State private var paginationModel: PaginatableUserUploadedFiles? = nil
    @State private var searchOrder: UserUploadsOrder = .newer

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
        .toolbar {
            SearchOrderButton(searchOrder: $searchOrder, possibleCases: [.newer, .older])
        }
        .onChange(of: searchOrder, initial: true) { oldValue, newValue in
            guard paginationModel == nil || (newValue != oldValue) else { return }
            Task<Void, Never> {
                do {
                    paginationModel = try await PaginatableUserUploadedFiles(
                        appDatabase: appDatabase,
                        username: username,
                        order: searchOrder,
                        fileCachingStrategy: isAccountUser ? .saveAll : .replaceExisting
                    )
                } catch {
                    logger.error("Error loading user uploads: \(error)")
                }
            }
        }
    }
}

#Preview {
    UploadsView(username: "CommonExploerTester")
}
