//
//  MediaFileEntity.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 31.10.24.
//

import AppIntents
import CommonsAPI
import Foundation
import GRDB
import MapKit
import os.log

@AppEnum(schema: .reader.documentKind)
enum ReaderDocumentKind: String, AppEnum {
    case photo
    case video
    case audio


    static let caseDisplayRepresentations: [ReaderDocumentKind: DisplayRepresentation] = [
        .photo: "Photo",
        .video: "Video",
        .audio: "Audio",
    ]
}


/// Represents the MediaFile as an AppEntity to appear in (siri) system search etc.
@AppEntity(schema: .reader.document)
struct MediaFileAppEntity: AppEntity {
    var id: String

    var title: String

    @Property(title: "Caption")
    var caption: String?

    @Property(title: "Categories")
    var categories: [String]?

    var kind: ReaderDocumentKind
    var width: Int?
    var height: Int?

    var localImageURL: URL?

    static let defaultQuery = MediaFileAppEntityQuery()


    var displayRepresentation: DisplayRepresentation {
        var image: DisplayRepresentation.Image?
        if let localImageURL {
            image = .init(url: localImageURL)
        }
        if let caption {
            return DisplayRepresentation(title: "\(title)", subtitle: "\(caption)", image: image)
        } else {
            return DisplayRepresentation(title: "\(title)", image: image)
        }

    }
}

extension MediaFileAppEntity {
    init(_ mediaFileModel: MediaFile) {
        self.id = mediaFileModel.id
        self.title = mediaFileModel.name

        let currentLanguageCode = Locale.current.language.languageCode?.identifier ?? "en"

        self.caption = mediaFileModel.captions.first { $0.languageCode == currentLanguageCode }?.string
        self.categories = mediaFileModel.categories
        //        if let coordinate = mediaFileModel.coordinate {
        //            self.location = try await CLGeocoder().reverseGeocodeLocation(.init(latitude: coordinate.latitude, longitude: coordinate.longitude)).first
        //        }
    }
}

struct MediaFileAppEntityQuery: EntityStringQuery, EnumerableEntityQuery {
    @Dependency
    var appDatabase: AppDatabase

    static let findIntentDescription = IntentDescription("Find Files", searchKeywords: ["Wiki", "Commons", "uploads"], resultValueName: "File")

    func suggestedEntities() async throws -> [MediaFileAppEntity] {
        return try await appDatabase.reader
            .read { db in
                try MediaFile
                    .limit(3)
                    .fetchAll(db)
            }
            .map(MediaFileAppEntity.init)
    }
    // TODO/IDEA: Alternative to EnumerableEntityQuery -> EntityPropertyQuery for better performance eg. when performing network search!:
    // https://developer.apple.com/documentation/appintents/entitypropertyquery
    // https://developer.apple.com/documentation/appintents/acceleratingappinteractionswithappintents#Enable-Find-intents
    func allEntities() async throws -> [MediaFileAppEntity] {
        try await appDatabase.reader
            .read { db in
                try MediaFile.fetchAll(db)
            }
            .map(MediaFileAppEntity.init)
    }


    func entities(matching string: String) async throws -> [MediaFileAppEntity] {
        Logger().debug("[MediaFileAppEntityQuery] Query for string \"\(string)\"")
        // using FTS: https://github.com/groue/GRDB.swift/blob/master/Documentation/FullTextSearch.md#choosing-the-full-text-engine
        return
            try appDatabase
            .fetchAllFiles(matchingPhrase: string)
            .map(MediaFileAppEntity.init)
    }

    func entities(for identifiers: [MediaFileAppEntity.ID]) async throws -> [MediaFileAppEntity] {
        Logger().debug("[MediaFileAppEntityQuery] Query for IDs \(identifiers)")

        return try await appDatabase.reader
            .read { db in
                try MediaFile.fetchAll(db)
            }
            .map(MediaFileAppEntity.init)
    }
}
