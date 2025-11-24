////
////  ConcaveHull.swift
////  ConcaveHull
////
////  Created by Sany Maamari on 09/03/2017.
////  Copyright © 2017 AppProviders. All rights reserved.
////  (c) 2014-2016, Andrii Heonia
////  Hull.js, a JavaScript library for concave hull generation by set of points.
////  https://github.com/AndriiHeonia/hull
////
//
//import Foundation
//import MapKit
//import GEOSwift
//
//GEOSwift.
//
//
//
//
//nonisolated enum ConcaveHull {
//
//    /**
//     This main function allows to create the hull of a set of point by defining the desired concavity of the return
//     hull. In this function, there is no need for the format
//     - parameter coordinates: The list of point as CLLocationCoordinate2D
//     - returns: An array of point in the same format as pointSet, which is the hull of the pointSet
//     */
//    static func calculateHull(coordinates: [CLLocationCoordinate2D], concavity: Double = 20) -> [CLLocationCoordinate2D] {
//        
//        guard let firstCoordinate = coordinates.first else { return coordinates }
//        
//        if coordinates.count < 4 {
//            return coordinates
//        }
//        
//        let areAllPointsIdentical = coordinates.allSatisfy { $0 == firstCoordinate }
//        
//        if areAllPointsIdentical {
//            return coordinates
//        }
//
//        let pointSet: [Point] = coordinates.map {
//            Point(x: $0.latitude, y: $0.longitude)
//        }
//
//        let hull = HullHelper().getHull(pointSet, concavity: concavity)
//
//        return hull.map { point in
//            CLLocationCoordinate2D(latitude: point[0], longitude: point[1])
//        }
//    }
//}
//
