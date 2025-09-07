////
////  PaginatableCategoryFiles.swift
////  CommonsFinder
////
////  Created by Tom Brewe on 12.03.25.
////
//
//import CommonsAPI
//import SwiftUI
//
//@Observable
//final class
//    PaginatableCategoryFiles: PaginatableMediaFiles
//{
//    let categoryName: String
//
//    @ObservationIgnored
//    private var continueString: String?
//
//    init(appDatabase: AppDatabase, categoryName: String) async throws {
//        self.categoryName = categoryName
//        try await super.init(appDatabase: appDatabase)
//    }
//
//    override internal func
//        fetchRawContinuePaginationItems() async throws -> (items: [FileMetadata], reachedEnd: Bool)
//    {
//        let result = try await CommonsAPI.API.shared.listCategoryImagesRaw(
//            of: categoryName,
//            continueString: continueString
//        )
//
//        let canContinue = result.continueString != nil
//        self.continueString = result.continueString
//        return (result.files, canContinue)
//    }
//}
