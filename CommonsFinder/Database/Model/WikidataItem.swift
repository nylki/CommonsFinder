//
//  WikidataItem.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 29.03.25.
//

import CoreLocation
import Foundation
import GRDB

struct WikidataItem: Identifiable, Equatable, Hashable, Sendable, Codable {
    typealias LanguageCode = String

    let id: String
    /// this is used to re-fetch label and description if the user's locale was changed
    /// Ideally we might save multiple translations here, but the sparql API and wbgetentities work a bit differently
    /// making them not that compatible when using together, so we simply store the main language reported back
    /// and fetch more translations on demand
    var preferredLanguageAtFetchDate: LanguageCode
    var fetchDate: Date
    var label: String?
    var description: String?
    var aliases: [String]
    var commonsCategory: String?
    /// the instance as Q-Item
    var instances: [String]
    var latitude: Double?
    var longitude: Double?

    /// the designated Wikidata image
    var image: URL?
}

extension WikidataItem {
    var location: CLLocationCoordinate2D? {
        if let latitude, let longitude {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        } else {
            nil
        }
    }
    var url: URL {
        URL(string: "https://www.wikidata.org/wiki/\(id)")!
    }
}

extension WikidataItem: FetchableRecord, MutablePersistableRecord {
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let fetchDate = Column(CodingKeys.fetchDate)
        static let preferredLanguageAtFetchDate = Column(CodingKeys.preferredLanguageAtFetchDate)
        static let label = Column(CodingKeys.label)
        static let description = Column(CodingKeys.description)
        static let commonsCategory = Column(CodingKeys.commonsCategory)
        static let instances = Column(CodingKeys.instances)
        static let image = Column(CodingKeys.image)
    }
}


extension WikidataItem {
    static func randomItem(id: String) -> Self {
        .init(
            id: id, preferredLanguageAtFetchDate: "en", fetchDate: .now, label: "Lorem \(id)", description: "third planet from the Sun in the Solar System \(id)",
            aliases: ["Gaia \(id)", "🌍 \(id)", "The Blue Planet \(id)"], commonsCategory: "Earth", instances: ["Q3504248"], latitude: nil, longitude: nil,
            image: URL(string: "https://commons.wikimedia.org/wiki/File:Terrestrial_planet_size_comparisons_edit.jpg")!)
    }

    static var earth: Self {
        .init(
            id: "Q2", preferredLanguageAtFetchDate: "en", fetchDate: .now, label: "Earth", description: "third planet from the Sun in the Solar System", aliases: ["Gaia", "🌍", "The Blue Planet"],
            commonsCategory: "Earth", instances: ["Q3504248"], latitude: nil, longitude: nil,
            image: URL(string: "https://commons.wikimedia.org/wiki/File:Terrestrial_planet_size_comparisons_edit.jpg")!)
    }

    static var earthExtraLongLabel: Self {
        .init(
            id: "Q2_X", preferredLanguageAtFetchDate: "en", fetchDate: .now, label: "Earth of the Solar System with Lorem Ipsum Dolor Sitit",
            description: "third planet from the Sun in the Solar System and also known as Gaia or \"The Blue Planet\" with the UTF-8 symbol 🌍", aliases: ["Gaia", "🌍", "The Blue Planet"],
            commonsCategory: "Earth", instances: ["Q3504248"], latitude: nil, longitude: nil,
            image: URL(string: "https://commons.wikimedia.org/wiki/File:Terrestrial_planet_size_comparisons_edit.jpg")!)
    }

    static var testItemNoDesc: Self {
        .init(
            id: "Q2_Y", preferredLanguageAtFetchDate: "en", fetchDate: .now, label: "Lorem", description: nil, aliases: ["Gaia", "🌍", "The Blue Planet"], commonsCategory: "Earth",
            instances: ["Q3504248"], latitude: nil, longitude: nil, image: URL(string: "https://commons.wikimedia.org/wiki/File:Terrestrial_planet_size_comparisons_edit.jpg")!)
    }

    static var testItemNoLabel: Self {
        .init(
            id: "Q42", preferredLanguageAtFetchDate: "en", fetchDate: .now, label: nil, description: nil, aliases: ["Gaia", "🌍", "The Blue Planet"], commonsCategory: "Earth", instances: ["Q5"],
            latitude: nil, longitude: nil, image: URL(string: "https://commons.wikimedia.org/wiki/File:Terrestrial_planet_size_comparisons_edit.jpg")!)
    }
}
