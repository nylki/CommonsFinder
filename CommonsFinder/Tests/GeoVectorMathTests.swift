//
//  GeoVectorMathTests.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 26.07.25.
//


import CoreLocation
import Testing

@Suite("GeoVectorMathTests")
nonisolated struct GeoVectorMathTests {
    nonisolated struct GeoTestData {
        let start: CLLocationCoordinate2D
        let bearing: CLLocationDegrees
        /// distance in meters
        let distance: CLLocationDistance
        let expectedDest: CLLocationCoordinate2D
    }

    // Greenwich, Prime Merdian metal line mark in Greenwich A..B
    // https://www.openstreetmap.org/way/268533450
    static let primeMeridianA = CLLocationCoordinate2D(latitude: 51.4778629, longitude: -0.0014742)
    static let primeMeridianB = CLLocationCoordinate2D(latitude: 51.4780228, longitude: -0.0014751)

    static let testData: [GeoTestData] = [
        .init(
            start: primeMeridianA,
            bearing: 0,
            distance: 17.78,
            expectedDest: primeMeridianB
        ),
        .init(
            start: .init(latitude: 0, longitude: 0),
            bearing: 90,
            distance: 111_320,
            expectedDest: .init(latitude: 0, longitude: 1)
        ),
        .init(
            start: .init(latitude: 0, longitude: 0),
            bearing: -90,
            distance: 111_320,
            expectedDest: .init(latitude: 0, longitude: -1)
        ),
    ]

    @Test("Destination from start location with bearing and distance", arguments: testData)
    func testGetDestination(testData: GeoTestData) {
        let dest = GeoVectorMath.getDestination(
            fromStart: testData.start,
            bearing: testData.bearing,
            distance: testData.distance
        )
        print("destination: \(dest.latitude), \(dest.longitude)")


        let expected = testData.expectedDest
        let actualLoc = CLLocation(latitude: dest.latitude, longitude: dest.longitude)
        let expectedLoc = CLLocation(latitude: expected.latitude, longitude: expected.longitude)

        let errorDistance = actualLoc.distance(from: expectedLoc)


        // NOTE: since we use an mean radius of the earth, there is some deviation for longer distances
        // depending on where start and end locations are. The use-case for this app are distances of 10 meter - 5km

        let tolerance: CLLocationDistance = max(0.1, testData.distance * 0.0015)  // 0.15% of distance, minimum 10 cm

        print("→ error: \(errorDistance)m (tolerance: \(tolerance)m) for distance \(testData.distance)m")

        #expect(
            errorDistance <= tolerance,
            "Expected location within \(tolerance)m, got \(errorDistance)m"
        )
    }
}
