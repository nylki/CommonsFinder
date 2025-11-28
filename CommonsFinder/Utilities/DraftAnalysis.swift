//
//  DraftAnalysis.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.07.25.
//

import Accelerate
import Algorithms
import CommonsAPI
import CoreLocation
import Foundation
import GeoToolbox
import MapKit
import RegexBuilder
import Vision
import os.log

nonisolated enum DraftAnalysis {
    @concurrent static func analyze(draft: MediaFileDraft) async -> DraftAnalysisResult? {

        guard let fileURL = draft.localFileURL() else { return nil }
        let handler = ImageRequestHandler(fileURL)
        let exifData = draft.loadExifData()

        let coordinate: CLLocationCoordinate2D? =
            if case .userDefinedLocation(latitude: let lat, longitude: let lon, _) = draft.locationHandling {
                .init(latitude: lat, longitude: lon)
            } else {
                exifData?.coordinate
            }

        let nearbyCategoryTask = Task<[Category], Never> { @concurrent in
            guard let coordinate else { return [] }
            let categories = await fetchNearbyCategories(
                coordinate: coordinate,
                horizontalError: exifData?.hPositioningError,
                bearing: exifData?.normalizedBearing
            )
            return categories
        }

        async let detectSmudgeOperation = detectSmudgesAndLowQuality(imageRequestHandler: handler)
        async let detectFacesOperation = detectFaces(imageRequestHandler: handler)
        //        async let cvcClassifyOperation = fetchComputerVisionCategories(imageRequestHandler: handler)
        async let nearbyCategoriesOperation = nearbyCategoryTask.value

        let (isLowQuality, faceCount, nearbyCategories) = await (detectSmudgeOperation, detectFacesOperation, nearbyCategoriesOperation)

        return .init(isLowQuality: isLowQuality, nearbyCategories: nearbyCategories, faceCount: faceCount)
    }


    /// detectSmudgesAndLowQuality
    /// - Parameter imageRequestHandler: A shared handler
    /// - Returns: `Bool`
    ///    `true` = is probably very low quality or has lens smudges and needs user confirmation before upload
    ///    `false` = is probably a good image to upload
    private static func detectSmudgesAndLowQuality(imageRequestHandler: ImageRequestHandler) async -> Bool {

        if #available(iOS 26.0, *) {
            let smudgeRequest = DetectLensSmudgeRequest()
            let aestheticRequest = CalculateImageAestheticsScoresRequest()
            do {
                async let smudgeRequestTask = imageRequestHandler.perform(smudgeRequest)
                async let aestheticRequestTask = imageRequestHandler.perform(aestheticRequest)

                let (smudgeObservation, aestheticObservation) = try await (smudgeRequestTask, aestheticRequestTask)
                logger.info("smudged? \(smudgeObservation.confidence)")
                logger.info("aesthetic score: \(aestheticObservation.overallScore) ((range: -1 awful...1 picture of the day) utility image: \(aestheticObservation.isUtility)")
                return smudgeObservation.confidence > 0.8 || (!aestheticObservation.isUtility && aestheticObservation.overallScore < -0.7)
            } catch {
                logger.error("Failed to perform smudge or aesthetic detection")
                return false
            }
        } else {
            return false
        }
    }

    private static func detectFaces(imageRequestHandler: ImageRequestHandler) async -> Int? {
        let detectFacesRequest = DetectFaceRectanglesRequest()

        do {
            let faceObservations = try await imageRequestHandler.perform(detectFacesRequest)
            return faceObservations.count
        } catch {
            logger.error("Failed to analyze image for faces \(error)")
            return nil
        }
    }


    private static func fetchComputerVisionCategories(imageRequestHandler: ImageRequestHandler) async -> [Category] {
        let request = ClassifyImageRequest()


        do {
            let results: () = try await imageRequestHandler.perform(request)
                .filter { $0.hasMinimumRecall(0.01, forPrecision: 0.9) }
                .forEach { observation in
                    logger.info("image classification: \(observation.identifier) (\(observation.confidence))")
                }
        } catch {
            logger.error("Failed to classify draft image \(error)")
        }

        return []
    }

    struct SearchCircle {
        let coordinate: CLLocationCoordinate2D
        let radius: CLLocationDistance
    }

    private static func fetchLineOfSightCategories(startCoordinate: CLLocationCoordinate2D, bearing: CLLocationDegrees, horizontalError: CLLocationDistance) async -> [Category] {
        /// along the line-of-sight, from camera location along the bearing, circle with increasing diameter are fetched in regular distances from each other
        /// to gather likely candites of depicted category items.

        // distances from startCoordinate along the bearing angle
        let distances = [
            // to include a circle at the coordinate itself, we have to offset the first distance behind the camera coordinates
            // by atleast the amount of the horizontal error and a bit more.
            -(50 + horizontalError),
            0.0, 50, 100, 250, 500, 750, 1000, 1500, 2000, 3000,
        ]

        // calculate a coordinate and search diameter for each defined distance
        let circles: [SearchCircle] = distances.adjacentPairs()
            .map { (prevDistance, distance) in
                let coordinate = GeoVectorMath.getDestination(fromStart: startCoordinate, bearing: bearing, distance: distance)

                // the circle overlaps the previous circle up to the previous circle's center.
                let radius = (distance - prevDistance)
                return SearchCircle(coordinate: coordinate, radius: radius)
            }

        var categories: [Category] = []
        for circles in circles.chunks(ofCount: 2) {
            if categories.count >= 10 { break }
            categories.append(contentsOf: await fetchCategories(in: circles))
        }

        return categories

    }

    private static func fetchCategories(in circles: any Collection<SearchCircle>) async -> [Category] {

        let apiItems = await withTaskGroup(returning: [GenericWikidataItem].self) { @concurrent group in
            for circle in circles {
                group.addTask {
                    do {
                        let categories = try await CommonsAPI.API.shared
                            .getWikidataItemsAroundCoordinate(
                                circle.coordinate,
                                kilometerRadius: circle.radius / 1000,
                                limit: 50,
                                languageCode: Locale.current.wikiLanguageCodeIdentifier
                            )

                        return categories

                    } catch {
                        logger.error("Failed to getWikidataItemsAroundCoordinate \(circle.coordinate.latitude), \(circle.coordinate.longitude) \(error)")
                        return []
                    }
                }
            }

            var result: [GenericWikidataItem] = []
            for await taskResult in group {
                // Set operation name as key and operation result as value
                result.append(contentsOf: taskResult)
            }
            return result.uniqued(on: \.id)
        }

        return apiItems.map(Category.init)
    }

    private static func fetchCategoriesWithAreas(around coordinate: CLLocationCoordinate2D, radiusMeters: CLLocationDistance, minAreaQm: Double, limit: Int = 25) async -> [Category] {
        do {
            let result = try await CommonsAPI.API.shared
                .getWikidataItemsAroundCoordinate(
                    coordinate,
                    kilometerRadius: radiusMeters / 1000,
                    limit: limit,
                    minArea: minAreaQm,
                    languageCode: Locale.current.wikiLanguageCodeIdentifier
                )
                .map(Category.init)

            return result
        } catch {
            logger.error("failed to fetch categories with areas around coordinate \(error)")
            return []
        }
    }

    private static func fetchExpandingCircleCategories(around coordinate: CLLocationCoordinate2D) async -> [Category] {
        /// circle with increasing diameter are fetched at the coordinate

        do {
            // TODO: if possible take depth and "outside" classification into account? eg. if outside
            // or wide image depth, adjust radius? otherwise if classified as indoors, prefer lower radius?

            var result: [Category] = []
            let kmDiameters = [0.1, 0.33, 0.66, 1, 3]


            for kmDiameter in kmDiameters {
                let limit = 50
                let categories = try await CommonsAPI.API.shared
                    .getWikidataItemsAroundCoordinate(
                        coordinate,
                        kilometerRadius: kmDiameter,
                        limit: limit,
                        languageCode: Locale.current.wikiLanguageCodeIdentifier
                    )
                    .map(Category.init)

                result.append(contentsOf: categories)

                // if this time the limit was reached, we stop the radius search since we won't profit
                // from increasing the radius any further without also increasing the radius.
                if categories.count >= limit {
                    break
                }
            }

            return result.uniqued { ($0.wikidataId ?? $0.commonsCategory) }

        } catch {
            logger.error("Failed to fetch nearby categories for draft image \(error)")
            return []
        }
    }

    private static func fetchCategoriesByReverseMapKitGeocoding(coordinate: CLLocationCoordinate2D) async throws -> [Category] {
        let referenceCLLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        let placemark = try await coordinate.reverseGeocodingRequest()
        // TODO: in iOS 26 only, use MKReverseGeocodingRequest to access .address.shortAddress
        //        async let mapItemRequest = await geocodingRequest?.mapItems.first

        var result: [Category] = []

        if let placemark {

            if let thoroughfare = placemark.thoroughfare, let city = placemark.locality {
                let shortAddress = "\(thoroughfare), \(city)"

                var streetCategories: [Category] = []
                streetCategories += try await APIUtils.searchCategories(for: shortAddress)

                if streetCategories.isEmpty,
                    let street = shortAddress.components(separatedBy: .decimalDigits).first
                {
                    streetCategories += try await APIUtils.searchCategories(for: street)
                }

                streetCategories =
                    streetCategories.filter {
                        guard let latitude = $0.latitude, let longitude = $0.longitude else {
                            return false
                        }
                        let distanceFromReference = CLLocation(latitude: latitude, longitude: longitude)
                            .distance(from: referenceCLLocation)

                        return distanceFromReference < 3000
                    }
                    .sorted(by: { a, b in
                        sortCategoriesByDistance(to: referenceCLLocation, a: a, b: b)
                    })

                result.insert(contentsOf: streetCategories.prefix(1), at: 0)
            } else if let water = placemark.ocean ?? placemark.inlandWater {
                let waterCategories = try await APIUtils.searchCategories(for: water)
                    .filter { category in
                        // canal, river, lake, better to do it in the query with broader water filter
                        Set(["Q12284", "Q4022", "Q23397"]).intersection(category.instances).isEmpty == false
                    }
                    .sorted(by: { a, b in
                        sortCategoriesByDistance(to: referenceCLLocation, a: a, b: b)
                    })

                result.insert(contentsOf: waterCategories.prefix(1), at: 0)

            }

            //            let relevantLargeAreaPOIs: [MKPointOfInterestCategory] = [
            //                .airport, .amusementPark, .aquarium, .beach, .campground, .castle, .conventionCenter, .fairground, .foodMarket, .fortress, .golf, .goKart, .hiking, .kayaking, .landmark, .marina,
            //                .museum, .musicVenue, .nationalMonument, .nationalPark, .park, .publicTransport, .rvPark, .skating, .skatePark, .spa, .soccer, .skiing, .stadium, .swimming, .surfing, .tennis,
            //                .theater, .university, .volleyball, .zoo,
            //            ]

            // TODO: use this with iOS 26 mapItem via MKReverseGeocodingRequest
            // Parks, Landmarks, beach, zoo etc.
            //            if let mkPOICategory = item.pointOfInterestCategory,
            //                var name = item.name,
            //                relevantLargeAreaPOIs.contains(mkPOICategory)
            //            {
            //
            //                if let dashSplit = name.split(separator: " - ").first {
            //                    name = String(dashSplit)
            //                }
            //                let areaOfInterestCategories = try await APIUtils.searchCategories(for: name)
            //                    .filterByMaxDistance(maxDistance: 3000, to: referenceCLLocation)
            //                    //                    .filter(\.isSpecialOrLandmarkPlace)
            //                    .sorted(by: { a, b in
            //                        sortCategoriesByDistance(to: referenceCLLocation, a: a, b: b)
            //                    })
            //
            //                if let areaOfInterest = areaOfInterestCategories.first,
            //                    let coord = areaOfInterest.coordinate
            //                {
            //                    //Also include the best match as well as items that are (also) very close to the found item (eg. 100 meters)
            //                    // This helps with landmarks that have multiple entries but are not quite the same (eg. older building vs. newer).
            //                    let closeAreas = areaOfInterestCategories.filterByMaxDistance(
            //                        maxDistance: 200,
            //                        to: CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            //                    )
            //                    result.insert(contentsOf: [areaOfInterest] + closeAreas, at: 0)
            //                }
            //
            //            }
        }
        return result
    }

    private static func fetchNearbyCategories(coordinate: CLLocationCoordinate2D, horizontalError: CLLocationDistance?, bearing: CLLocationDegrees?) async -> [Category] {
        let refLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        var searchResult: [Category]
        let scoreMethod: ScoreCalculationMethod

        let isRelativelyPreciseLocation: Bool

        if let horizontalError, horizontalError < 75 {
            isRelativelyPreciseLocation = true
            if let bearing {
                scoreMethod = .lowDistanceLowBearingDifference
                async let areaSearch = fetchCategoriesWithAreas(around: coordinate, radiusMeters: 2000, minAreaQm: 200, limit: 5)
                async let lineOfSightSearch = fetchLineOfSightCategories(startCoordinate: coordinate, bearing: bearing, horizontalError: horizontalError)
                searchResult = await (areaSearch + lineOfSightSearch)
            } else {

                scoreMethod = .lowDistance
                async let areaSearch = fetchCategoriesWithAreas(around: coordinate, radiusMeters: 2000, minAreaQm: 200, limit: 5)
                async let expandingSearch = await fetchExpandingCircleCategories(around: coordinate)
                searchResult = await (areaSearch + expandingSearch)
            }
        } else {
            isRelativelyPreciseLocation = false
            scoreMethod = .lowDistanceHighArea
            // if the horizontal error is too big, we fall back to a query that fetches only wikidata items
            // that have an area, so items that are usually bigger.
            let radius = if let horizontalError { horizontalError / 2.0 } else { 5000.0 }
            // items to suggest should be atleast 10% the size of error/precision radius to be big enough to be relevant
            // (i.e: we don't necessarily want smaller item only because they have an area)
            let minAreaSqm = (radius * 2) * 0.1
            searchResult = await fetchCategoriesWithAreas(around: coordinate, radiusMeters: radius, minAreaQm: minAreaSqm)
        }

        searchResult = searchResult.uniqued { ($0.wikidataId ?? $0.commonsCategory) }


        let scoredResults = calculateSuggestionScores(
            of: searchResult,
            referenceLocation: refLoc,
            referenceBearing: bearing,
            method: scoreMethod
        )

        var finalResult = scoredResults.map(\.0)

        if isRelativelyPreciseLocation {
            do {
                // augment the search with cross-referencing items via reverse-geo-coding the cam coordinates via MapKit
                // and then querying the landmark/street/ocean/etc. via wikimedia APIs and apply some specialized filters
                // to get categories that may have been missed in the search before.
                // and
                let mapKitCategorySuggestions = try await fetchCategoriesByReverseMapKitGeocoding(coordinate: coordinate)
                finalResult.insert(contentsOf: mapKitCategorySuggestions, at: 0)
            } catch {
                logger.error("Error fetching mapkit category suggestions \(error)")
            }
        }

        return finalResult.uniqued { ($0.wikidataId ?? $0.commonsCategory) }
    }

    private enum ScoreCalculationMethod {
        case lowDistance
        case lowDistanceLowBearingDifference
        case lowDistanceHighArea
    }

    static private func calculateSuggestionScores(
        of categories: [Category],
        referenceLocation: CLLocation,
        referenceBearing: CLLocationDegrees?,
        method: ScoreCalculationMethod
    ) -> [(Category, score: Double)] {
        var minDist = Double.greatestFiniteMagnitude
        var maxDist = 0.0
        var minArea = Double.greatestFiniteMagnitude
        var maxArea = 0.0
        var minAngle: CLLocationDegrees = Double.greatestFiniteMagnitude
        var maxAngle: CLLocationDegrees = 0

        var distances: [CLLocationCoordinate2D: CLLocationDistance] = [:]


        // determine above min and max values used for score calculations and precalc distances for later
        for category in categories {
            guard let categoryCoordinate = category.coordinate else { continue }

            let distance = CLLocation(
                latitude: categoryCoordinate.latitude,
                longitude: categoryCoordinate.longitude
            )
            .distance(from: referenceLocation)

            distances[categoryCoordinate] = distance
            minDist = min(minDist, distance)
            maxDist = max(maxDist, distance)

            if let referenceBearing {
                let angle = GeoVectorMath.calculateAngleBetween(
                    cameraLocation: referenceLocation.coordinate,
                    cameraBearing: referenceBearing,
                    targetLocation: categoryCoordinate
                )
                minAngle = min(minAngle, angle)
                maxAngle = max(maxAngle, angle)
            }

            if let areaSqm = category.areaSqm {
                minArea = min(minArea, areaSqm)
                maxArea = max(maxArea, areaSqm)
            }
        }

        let scoredCategories: [(Category, score: Double)] = categories.map {
            guard let categoryCoordinate = $0.coordinate,
                let distance = distances[categoryCoordinate]
            else {
                assertionFailure()
                return ($0, 0.0)
            }

            let distanceScore = 1 - distance.interpolate(from: minDist..<maxDist, to: 0.0..<1.0)
            let score: Double

            switch method {
            case .lowDistance:
                score = distanceScore
            case .lowDistanceHighArea:
                guard let areaSqm = $0.areaSqm else { return ($0, 0) }
                let areaScore = areaSqm.interpolate(from: minArea..<maxArea, to: 0.0..<1.0)
                score = (distanceScore + areaScore) / 2
            case .lowDistanceLowBearingDifference:
                guard let referenceBearing else { return ($0, 0) }
                let angle = GeoVectorMath.calculateAngleBetween(
                    cameraLocation: referenceLocation.coordinate,
                    cameraBearing: referenceBearing,
                    targetLocation: categoryCoordinate
                )
                let angleScore = 1 - angle.interpolate(from: minAngle..<maxAngle, to: 0.0..<1.0)
                score = (distanceScore + angleScore) / 2

            }
            return ($0, score: score)
        }

        return scoredCategories.sorted(by: \.score, .orderedDescending)
    }

}

enum CategoryGeoSuggestionStrategy {
    case lineOfSight
    case expandingCircle
}

nonisolated extension [Category] {
    func filterByMaxDistance(maxDistance: CLLocationDistance, to location: CLLocation) -> Self {
        filter { category in
            guard let latitude = category.latitude, let longitude = category.longitude else {
                return false
            }
            let distanceFromReference = CLLocation(latitude: latitude, longitude: longitude)
                .distance(from: location)

            return distanceFromReference < maxDistance
        }

    }
}


extension Category {

    /// determines if the item encompasses likely a large area or has a long length, eg. lakes, seas, parks, cities and rivers, streets, roads
    fileprivate var isAreaOrLongItem: Bool {
        // FIXME: NOTE! these are just a selection of relevant wikidata items
        let areaIDs: Set<String> = ["Q23397", "Q22698", "Q4421"]
        let lengthIDs: Set<String> = ["Q4022", "Q79007", "Q34442", "Q174782"]
        let relevantIDs = areaIDs.union(lengthIDs)
        let instances = Set(instances)

        return instances.intersection(relevantIDs).isEmpty == false
    }


    /// non-street and non-lake, non-river, non-ocean
    fileprivate var isSpecialOrLandmarkPlace: Bool {
        // parks, harbour, train station, desert, island, landmark etc.
        let matchingsIDs: Set<String> = [
            "Q213205", "Q174782", "Q23442", "Q22698", "Q2319498", "Q1440300", "Q570116", "Q194195", "Q338112", "Q8514", "Q107425", "Q4421", "Q82794", "Q2578218", "Q1107656", "Q55488", "Q1248784",
            "Q44782",
        ]
        let instances = Set(instances)
        return instances.intersection(matchingsIDs).isEmpty == false
    }
}

extension FloatingPoint {
    fileprivate var degreesToRadians: Self { self * .pi / 180 }
    fileprivate var radiansToDegrees: Self { self * 180 / .pi }
}
