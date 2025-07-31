//
//  DraftAnalysis.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 11.07.25.
//

import Algorithms
import CommonsAPI
import CoreLocation
import Foundation
import Vision
import os.log

enum DraftAnalysis {
    static func analyze(draft: MediaFileDraft) async -> DraftAnalysisResult? {

        guard let fileURL = draft.localFileURL() else { return nil }
        let handler = ImageRequestHandler(fileURL)

        let nearbyCategoryTask = Task<[Category], Never> {
            guard let coordinate = draft.coordinate else { return [] }
            return await fetchNearbyCategories(coordinate: coordinate, bearing: draft.exifData?.destBearing)
        }

        async let detectSmudgeOperation = detectSmudgesAndLowQuality(imageRequestHandler: handler)
        async let detectFacesOperation = detectFaces(imageRequestHandler: handler)
        async let cvClassifyOperation = fetchComputerVisionCategories(imageRequestHandler: handler)
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
            let results = try await imageRequestHandler.perform(request)
                .filter { $0.hasMinimumRecall(0.01, forPrecision: 0.9) }
                .forEach { observation in
                    logger.info("image classification: \(observation.identifier) (\(observation.confidence))")
                }

            // TODO: search all results for categories and wikidata items
            // TODO: hardcoded combinations
            // eg. people outdoor, people waiting for trains
            // construction + City name
            //            CommonsAPI.API.shared.searchWikidataItems(term: <#T##String#>, languageCode: "en")
            //            CommonsAPI.API.shared.searchCategories(term: <#T##String#>, limit: <#T##ListLimit#>)


        } catch {
            logger.error("Failed to classify draft image \(error)")
        }

        return []
    }

    private static func fetchNearbyCategories(coordinate: CLLocationCoordinate2D, bearing: CLLocationDegrees?) async -> [Category] {
        do {

            async let placemarkRequest = await GeoPlacemarkCache.shared.getPlacemark(for: .init(latitude: coordinate.latitude, longitude: coordinate.longitude))

            // TODO: if possible take depth and "outside" classification into account? eg. if outside
            // or wide image depth, adjust radius? otherwise if classified as indoors, prefer lower radius?

            var result: [Category]

            result = try await CommonsAPI.API.shared
                .getWikidataItemsAroundCoordinate(
                    coordinate,
                    kilometerRadius: 0.1,
                    limit: 40,
                    languageCode: Locale.current.wikiLanguageCodeIdentifier
                )
                .map(Category.init)

            // Retry with a increasingly wider radius if result is empty
            if result.isEmpty || result.count < 15 {
                let res = try await CommonsAPI.API.shared
                    .getWikidataItemsAroundCoordinate(
                        coordinate,
                        kilometerRadius: 0.35,
                        limit: 50,
                        languageCode: Locale.current.wikiLanguageCodeIdentifier
                    )
                    .map(Category.init)

                result.append(contentsOf: res)
            }

            // Retry with a increasingly wider radius if result is empty
            if result.isEmpty || result.count < 30 {
                let res = try await CommonsAPI.API.shared
                    .getWikidataItemsAroundCoordinate(
                        coordinate,
                        kilometerRadius: 1,
                        limit: 50,
                        languageCode: Locale.current.wikiLanguageCodeIdentifier
                    )
                    .map(Category.init)

                result.append(contentsOf: res)
            }


            if result.isEmpty || result.count < 30 {
                let res = try await CommonsAPI.API.shared
                    .getWikidataItemsAroundCoordinate(
                        coordinate,
                        kilometerRadius: 3,
                        limit: 30,
                        languageCode: Locale.current.wikiLanguageCodeIdentifier
                    )
                    .map(Category.init)

                result.append(contentsOf: res)
            }

            if let placemark: CLPlacemark = await placemarkRequest {

                if let water = placemark.ocean ?? placemark.inlandWater {
                    // TODO: search for that location name
                    print("Placemark, water: \(water)")
                    // TODO: filter search for water, either results or search directly
                    let waterCategory = try await APIUtils.searchCategories(for: water)
                        .filter { category in
                            // river, lake, better to do it in the query with broader water filter
                            category.instances.contains("Q4022") || category.instances.contains("Q23397")
                        }
                        .first {
                            ($0.label ?? "").contains(water)
                        }

                    // FIXME: if there is any category that is an exact label or alias match,
                    // discard all others


                    if let waterCategory {
                        result = [waterCategory] + result
                    }
                } else if let name = placemark.name {
                    print("Placemark, name: \(name)")
                    let placemarkNameCategory = try await APIUtils.searchCategories(for: name)
                        .filter(\.isStreetLike)
                        .first {
                            ($0.label ?? "").contains(name)
                        }

                    if let placemarkNameCategory {
                        result = [placemarkNameCategory] + result
                    }


                }


                if let street = placemark.thoroughfare {
                    print("Placemark, street: \(street)")

                    var streetCategories: [Category] = []
                    if let locality = placemark.locality {
                        streetCategories = try await APIUtils.searchCategories(for: "\(street) \(locality)")
                    }

                    if streetCategories.isEmpty {
                        // try again only for the street without locality (city, town)
                        streetCategories = try await APIUtils.searchCategories(for: street)
                    }

                    let streetCategory: Category? =
                        streetCategories
                        // maybe better to do a query with broader water filter directly?
                        // or get wikidataID via osm api.
                        .filter(\.isStreetLike)
                        .first {
                            ($0.label ?? "").contains(street)
                        }

                    if let streetCategory {
                        result = [streetCategory] + result
                    }
                }
            }

            return
                result
                .uniqued { ($0.wikidataId ?? $0.commonsCategory) }
                .filter { category in
                    if category.isAreaOrLongItem {
                        // If we are dealing with a street, river or park still return true, because those are long-stretched or area items
                        // TODO: improve filter with actual area vs. distance!
                        return true
                    } else if let bearing, let categoryLocation = category.location {
                        let angle = GeoVectorMath.calculateAngleBetween(cameraLocation: coordinate, cameraBearing: bearing, targetLocation: categoryLocation)
                        return angle < 50
                    } else {
                        return true
                    }
                }

        } catch {
            logger.error("Failed to fetch nearby categories for draft image \(error)")
            return []
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

    fileprivate var isStreetLike: Bool {
        let streetLikeIDs: Set<String> = ["Q79007", "Q34442", "Q174782"]
        let instances = Set(instances)
        return instances.intersection(streetLikeIDs).isEmpty == false
    }
}

extension FloatingPoint {
    fileprivate var degreesToRadians: Self { self * .pi / 180 }
    fileprivate var radiansToDegrees: Self { self * 180 / .pi }
}
