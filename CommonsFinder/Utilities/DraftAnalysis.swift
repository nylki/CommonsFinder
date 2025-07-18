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

        var nearbyCategoryTask = Task<[Category], Never> {
            guard let coordinate = draft.coordinate else { return [] }
            return await fetchNearbyCategories(coordinate: coordinate)
        }

        async let detectSmudgeOperation = detectSmudgesAndLowQuality(imageRequestHandler: handler)
        async let detectFacesOperation = detectFaces(imageRequestHandler: handler)
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

    //
    //    private static func fetchComputerVisionCategories(fileURL: URL) async -> [Category] {
    //        let request = ClassifyImageRequest()
    //
    //
    //        do {
    //            let results = try await request.perform(on: fileURL)
    //                .filter { $0.hasMinimumRecall(0.01, forPrecision: 0.9) }
    //                .forEach { observation in
    //                    logger.info("\(observation.identifier) (\(observation.confidence))")
    //                }
    //
    //            // TODO: search all results for categories and wikidata items
    //            // TODO: hardcoded combinations
    //            // eg. people outdoor, people waiting for trains
    //            // construction + City name
    //            //            CommonsAPI.API.shared.searchWikidataItems(term: <#T##String#>, languageCode: "en")
    //            //            CommonsAPI.API.shared.searchCategories(term: <#T##String#>, limit: <#T##ListLimit#>)
    //
    //
    //        } catch {
    //            logger.error("Failed to classify draft image \(error)")
    //        }
    //
    //        return []
    //    }

    private static func fetchNearbyCategories(coordinate: CLLocationCoordinate2D) async -> [Category] {
        do {

            // TODO: if possible take depth and "outside" classification into account? eg. if outside
            // or wide image depth, adjust radius? otherwise if classified as indoors, prefer lower radius?

            var result: [GenericWikidataItem]

            result = try await CommonsAPI.API.shared.getWikidataItemsAroundCoordinate(
                coordinate,
                kilometerRadius: 1,
                limit: 40,
                languageCode: Locale.current.wikiLanguageCodeIdentifier
            )

            // Retry with a wider radius if result is empty
            if result.isEmpty {
                result = try await CommonsAPI.API.shared.getWikidataItemsAroundCoordinate(
                    coordinate,
                    kilometerRadius: 3,
                    limit: 10,
                    languageCode: Locale.current.wikiLanguageCodeIdentifier
                )
            }


            return
                result
                .uniqued(on: \.id)
                .map(Category.init)

        } catch {
            logger.error("Failed to fetch nearby categories for draft image \(error)")
            return []
        }
    }
}
