//
//  Category.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 29.03.25.
//

import CoreLocation
import Foundation
import GRDB

nonisolated struct Category: Identifiable, Equatable, Hashable, Sendable, Codable {
    typealias LanguageCode = String
    // todo used Tagged!?
    typealias WikidataID = String

    /// NOTE: `id` is a Database SQL id, prefer the `wikidataId` or `commonsCategory` for API requests!
    var id: Int64?

    var wikidataId: WikidataID?

    // If the item was merged with another,
    // then redirectToWikidataId has the ID of the preferred/merged item
    var redirectToWikidataId: WikidataID?

    var commonsCategory: String?

    /// this is used to re-fetch label and description if the user's locale was changed
    /// Ideally we might save multiple translations here, but the sparql API and wbgetentities work a bit differently
    /// making them not that compatible when using together, so we simply store the main language reported back
    /// and fetch more translations on demand
    var preferredLanguageAtFetchDate: LanguageCode
    var fetchDate: Date
    var label: String?
    var description: String?
    var aliases: [String]

    /// the instance as Q-Item
    var instances: [String]
    var latitude: Double?
    var longitude: Double?
    var areaSqm: Double?

    /// the designated Wikidata image
    var image: URL?

    var itemInteractionID: Int64?

    /// Initialize with non-optional wikidataId
    init(
        wikidataId: String, commonsCategory: String? = nil, redirectsToWikidataID: String? = nil, preferredLanguageAtFetchDate: LanguageCode = "en", fetchDate: Date = .now, label: String? = nil,
        description: String? = nil,
        aliases: [String] = [],
        instances: [String] = [], latitude: Double? = nil, longitude: Double? = nil, areaSqm: Double? = nil, image: URL? = nil
    ) {
        self.wikidataId = wikidataId
        self.commonsCategory = commonsCategory
        self.redirectToWikidataId = redirectsToWikidataID
        self.preferredLanguageAtFetchDate = preferredLanguageAtFetchDate
        self.fetchDate = fetchDate
        self.label = label
        self.description = description
        self.aliases = aliases
        self.instances = instances
        self.latitude = latitude
        self.longitude = longitude
        self.image = image
        self.areaSqm = areaSqm
    }

    /// Initialize with non-optional commonsCategory
    init(
        commonsCategory: String, wikidataId: String? = nil, redirectsToWikidataID: String? = nil, preferredLanguageAtFetchDate: LanguageCode = "en", fetchDate: Date = .now, label: String? = nil,
        description: String? = nil,
        aliases: [String] = [],
        instances: [String] = [], latitude: Double? = nil, longitude: Double? = nil, areaSqm: Double? = nil, image: URL? = nil
    ) {
        self.wikidataId = wikidataId
        self.commonsCategory = commonsCategory
        self.redirectToWikidataId = redirectsToWikidataID
        self.preferredLanguageAtFetchDate = preferredLanguageAtFetchDate
        self.fetchDate = fetchDate
        self.label = label
        self.description = description
        self.aliases = aliases
        self.instances = instances
        self.latitude = latitude
        self.longitude = longitude
        self.image = image
    }
}

nonisolated extension Category {
    var wikidataURL: URL? {
        if let wikidataId {
            URL(string: "https://www.wikidata.org/wiki/\(wikidataId)")
        } else {
            nil
        }
    }

    var commonsCategoryURL: URL? {
        if let commonsCategory {
            URL(string: "https://commons.wikimedia.org/wiki/Category:\(commonsCategory)")
        } else {
            nil
        }
    }
}

nonisolated extension Category: FetchableRecord, MutablePersistableRecord {
    nonisolated enum Columns {
        static let id = Column(CodingKeys.id)
        static let itemInteractiondID = Column(CodingKeys.itemInteractionID)
        static let wikidataId = Column(CodingKeys.wikidataId)
        static let redirectToWikidataId = Column(CodingKeys.redirectToWikidataId)
        static let commonsCategory = Column(CodingKeys.commonsCategory)

        static let fetchDate = Column(CodingKeys.fetchDate)
        static let preferredLanguageAtFetchDate = Column(CodingKeys.preferredLanguageAtFetchDate)
        static let label = Column(CodingKeys.label)
        static let description = Column(CodingKeys.description)

        static let instances = Column(CodingKeys.instances)
        static let image = Column(CodingKeys.image)
    }

    /// Updates the id after it has been inserted in the database.
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    nonisolated static let itemInteraction = belongsTo(ItemInteraction.self)

    var itemInteraction: QueryInterfaceRequest<ItemInteraction> {
        request(for: Self.itemInteraction)
    }

}

extension Category {
    static func randomItem(id: String) -> Self {
        .init(
            wikidataId: id, commonsCategory: UUID().uuidString, preferredLanguageAtFetchDate: "en", fetchDate: .distantPast, label: "Lorem \(id)",
            description: "third planet from the Sun in the Solar System \(id)",
            aliases: ["Gaia \(id)", "🌍 \(id)", "The Blue Planet \(id)"], instances: ["Q3504248"], latitude: nil, longitude: nil,
            image: URL(string: "https://commons.wikimedia.org/wiki/File:Terrestrial_planet_size_comparisons_edit.jpg")!)
    }

    static var earth: Self {
        .init(
            wikidataId: "Q2", commonsCategory: "Earth", preferredLanguageAtFetchDate: "en", fetchDate: .distantPast, label: "Earth", description: "third planet from the Sun in the Solar System",
            aliases: ["Gaia", "🌍", "The Blue Planet"], instances: ["Q3504248"], latitude: nil, longitude: nil,
            image: URL(string: "https://commons.wikimedia.org/wiki/File:Terrestrial_planet_size_comparisons_edit.jpg")!)
    }

    static var earthNoImage: Self {
        .init(
            wikidataId: "Q2", commonsCategory: "Earth", preferredLanguageAtFetchDate: "en", fetchDate: .distantPast, label: "Earth", description: "third planet from the Sun in the Solar System",
            aliases: ["Gaia", "🌍", "The Blue Planet"], instances: ["Q3504248"], latitude: nil, longitude: nil,
            image: nil)
    }

    static var earthExtraLongLabel: Self {
        .init(
            wikidataId: "Q2_X", commonsCategory: "Earth", preferredLanguageAtFetchDate: "en", fetchDate: .distantPast, label: "Earth of the Solar System with Lorem Ipsum Dolor Sitit",
            description: "third planet from the Sun in the Solar System and also known as Gaia or \"The Blue Planet\" with the UTF-8 symbol 🌍", aliases: ["Gaia", "🌍", "The Blue Planet"],
            instances: ["Q3504248"], latitude: nil, longitude: nil,
            image: URL(string: "https://commons.wikimedia.org/wiki/File:Terrestrial_planet_size_comparisons_edit.jpg")!)
    }

    static var testItemNoDesc: Self {
        .init(
            wikidataId: "Q2_Y", commonsCategory: "Earth", preferredLanguageAtFetchDate: "en", fetchDate: .distantPast, label: "Lorem", description: nil, aliases: ["Gaia", "🌍", "The Blue Planet"],
            instances: ["Q3504248"], latitude: nil, longitude: nil, image: URL(string: "https://commons.wikimedia.org/wiki/File:Terrestrial_planet_size_comparisons_edit.jpg")!)
    }

    static var testItemNoLabel: Self {
        .init(
            wikidataId: "Q42", commonsCategory: "Earth", preferredLanguageAtFetchDate: "en", fetchDate: .distantPast, label: nil, description: nil, aliases: ["Gaia", "🌍", "The Blue Planet"],
            instances: ["Q5"],
            latitude: nil, longitude: nil, image: URL(string: "https://commons.wikimedia.org/wiki/File:Terrestrial_planet_size_comparisons_edit.jpg")!)
    }
}
