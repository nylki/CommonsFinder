//
//  MediaFileInfo+Tags.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 20.04.25.
//

import Foundation

extension MediaFile {

    /// resolves Tags based on commons categories and depict items in MediaFile
    /// will return redirected (merged) items instead of original ones!
    @MainActor
    func resolveTags(appDatabase: AppDatabase, forceNetworkRefresh: Bool = false) async throws -> [TagItem] {
        let depictWikdataIDs: [String] =
            statements
            .filter(\.isDepicts)
            .compactMap(\.mainItem?.id)

        return try await DataAccess.fetchCombinedTagsFromDatabaseOrAPI(wikidataIDs: depictWikdataIDs, commonsCategories: categories, appDatabase: appDatabase)
    }
}
