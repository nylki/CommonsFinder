//
//  FileAnalysisHelpersTests.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 17.02.26.
//

import CoreLocation
import Testing

@Suite("File Analysis Helpers")
nonisolated struct FileAnalysisHelpersTests {

    @Test("Expanding circle stops querying when limit is reached")
    func expandingCircleStopsAtLimit() async {
        let coordinate = CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405)
        var callCount = 0

        let result = await FileAnalysisHelpers.fetchExpandingCircleCategories(
            around: coordinate,
            kilometerRadii: [0.1, 0.33, 0.66],
            limit: 50
        ) { _, kilometerRadius, _ in
            callCount += 1

            if kilometerRadius == 0.1 {
                return [Category(wikidataId: "Q1", commonsCategory: "First")]
            }

            if kilometerRadius == 0.33 {
                return (0..<50)
                    .map { idx in
                        Category(wikidataId: "Q\(idx + 100)", commonsCategory: "test-\(idx)")
                    }
            }

            Issue.record("Expanding-circle lookup should stop once limit-sized result is returned.")
            return []
        }

        #expect(callCount == 2)
        #expect(result.count == 51)
    }

    @Test("Expanding circle de-duplicates categories across radii")
    func expandingCircleDeduplicatesResults() async {
        let coordinate = CLLocationCoordinate2D(latitude: -1, longitude: 12)

        let result = await FileAnalysisHelpers.fetchExpandingCircleCategories(
            around: coordinate,
            kilometerRadii: [0.1, 0.33],
            limit: 50
        ) { _, kilometerRadius, _ in
            if kilometerRadius == 0.1 {
                return [
                    Category(wikidataId: "Q1", commonsCategory: "Universe"),
                    Category(wikidataId: "Q2", commonsCategory: "Earth"),
                    Category(wikidataId: "Q405", commonsCategory: "Moon"),
                ]
            }

            return [
                Category(wikidataId: "Q2", commonsCategory: "Earth"),
                Category(wikidataId: "Q405", commonsCategory: "Moon"),
                Category(wikidataId: "Q1234", commonsCategory: "something"),
            ]
        }

        #expect(result.count == 4)
        #expect(Set(result.compactMap(\.wikidataId)) == ["Q1", "Q2", "Q405", "Q1234"])
    }
}
