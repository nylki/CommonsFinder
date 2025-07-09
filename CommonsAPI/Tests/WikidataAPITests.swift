//
//  WikidataAPITests.swift
//  CommonsAPI
//
//  Created by Tom Brewe on 28.11.24.
//

import Testing
import os.log
import SwiftUI
@testable import CommonsAPI
import CoreLocation


@Suite("Wikidata E2E Tests", .serialized)
struct WikidataEndToEndTests {
    
    @Test("Searching Q-Items", arguments: [("tree", "en"), ("Baum", "de")])
    func searchItems(term: String, languageCode: String) async throws {
        let items = try await CommonsAPI.API.shared.searchWikidataItems(term: term, languageCode: languageCode)
        print("Q-Item results for \"\(term)\"")
        for item in items {
            print("\(item.id) (\(item.label))\n, \(item.description ?? "-")\n")
        }
        
        #expect(items.isEmpty == false, "We expect to find wikidata items this search term.")
    }
    
    @Test("Find Common Categories for  Q-Items", arguments: [["Q1", "Q2", "Q3", "Q42"]])
    func findCommonCategories(ids: [String]) async throws {
        let result = try await CommonsAPI.API.shared.findCategoriesForWikidataItems(ids, languageCode: "en")
        for item in result {
            print("\(item.id): \(item.commonsCategory ?? "-") \(item.label ?? "-") \(item.description ?? "-")")
        }
        #expect(!result.isEmpty, "We expect to find commons categories for those Q-items.")
    }
    
    @Test("Find Q-Items for Common Categories",
        arguments: [
            ["Universe", "SPARQL", "Berlin"],
            ["Erde" /*Village in Switzerland not Earth in German*/, "Earth"]
        ]
    )
    func findItemIDsForCommonCategories(categories: [String]) async throws {
        let result = try await CommonsAPI.API.shared.findWikidataItemsForCategories(categories, languageCode: "en")
        for item in result {
            print("\(item.id): \(item.commonsCategory ?? "-") \(item.label ?? "-") \(item.description ?? "-")")
        }
        #expect(!result.isEmpty, "We expect to find Q-items for those commons categories.")
    }
    
    @Test("fetch wikidata items by id", arguments:
            [["Q1"], ["Q1", "Q2", "Q42"]], ["en", "de"]
    )
    func fetchGenericWikidataItem(ids: [String], languageCode: String) async throws {
        let result = try await CommonsAPI.API.shared.fetchGenericWikidataItems(itemIDs: ids, languageCode: languageCode)
        #expect(result.count == ids.count)
        let resultIDs = Set(result.map(\.id))
        #expect(resultIDs == Set(ids))
        #expect(result.allSatisfy{ $0.label != nil })
    }
    
    @Test("fetch wikidata items around coordinate radius", arguments: [
        CLLocationCoordinate2D(latitude: 52.52, longitude: 13.404),
        .init(latitude: 37.789246, longitude: -122.402251)
    ]
    )
    func fetchWikidataItemsAroundCoordinateRadius(coordinate: CLLocationCoordinate2D) async throws {
        let result = try await CommonsAPI.API.shared.getWikidataItemsAroundCoordinate(coordinate, kilometerRadius: 0.5, limit: 3, languageCode: "en")
        
        #expect(result.isEmpty == false)
        #expect(result.count <= 3)
    }
}
