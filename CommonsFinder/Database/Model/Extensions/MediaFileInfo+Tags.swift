//
//  MediaFileInfo+Tags.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 20.04.25.
//

import Algorithms
import Foundation

extension MediaFile {

    /// resolves Tags based on commons categories and depict items in MediaFile
    /// will return redirected (merged) items instead of original ones!
    func resolveTags(appDatabase: AppDatabase, forceNetworkRefresh: Bool = false) async throws -> [TagItem] {
        let depictWikdataIDs: [String] =
            statements
            .filter(\.isDepicts)
            .compactMap(\.mainItem?.id)


        let result = try await DataAccess.fetchCombinedCategoriesFromDatabaseOrAPI(
            wikidataIDs: depictWikdataIDs,
            commonsCategories: categories,
            appDatabase: appDatabase
        )

        let depictIDsWithResolvedRedirects: [String] = depictWikdataIDs.map { depictID in
            result.redirectedIDs[depictID] ?? depictID
        }

        let categoriesSet = Set(categories)
        let depictIDSet = Set(depictIDsWithResolvedRedirects)

        return result.fetchedCategories.map {
            var picked: Set<TagType> = []
            if let wikidataID = $0.wikidataId, depictIDSet.contains(wikidataID) {
                picked.insert(.depict)
            }
            if let commonsCategory = $0.commonsCategory, categoriesSet.contains(commonsCategory) {
                picked.insert(.category)
            }
            return .init($0, pickedUsages: picked)
        }
    }
}
