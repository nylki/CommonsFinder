//
//  Hull.swift
//  Hull
//
//  Created by Sany Maamari on 09/03/2017.
//  Copyright © 2017 AppProviders. All rights reserved.
//  (c) 2014-2016, Andrii Heonia
//  Hull.js, a JavaScript library for concave hull generation by set of points.
//  https://github.com/AndriiHeonia/hull
//

import Foundation
import MapKit

nonisolated public class Hull {

    /**
     A public polygon created with the getPolygon Functions
     */
    public var polygon: MKPolygon = MKPolygon()

    /**
     The hull created with the hull functions
     */
    public var hull: [[Double]] = [[Double]]()


    /**
     The concavity paramater for the hull function, 20 is the default
    */
    public var concavity: Double

    /**
     Init function and set the concavity, if nil, the concavity will be equal to 20
     */
    public init(concavity: Double = 20) {
        self.concavity = concavity
    }

    /**
     This main function allows to create the hull of a set of point by defining the desired concavity of the return 
     hull. In this function, there is no need for the format
     - parameter coordinates: The list of point as CLLocationCoordinate2D
     - returns: An array of point in the same format as pointSet, which is the hull of the pointSet
     */
    public func hull(coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {

        if coordinates.count < 4 {
            return coordinates
        }

        let pointSet: [Point] = coordinates.map {
            Point(x: $0.latitude, y: $0.longitude)
        }

        hull = HullHelper().getHull(pointSet, concavity: self.concavity)

        
        return hull.map { point in
            CLLocationCoordinate2D(latitude: point[0], longitude: point[1])
        }
    }

    /**
     Create and set in the class a polygon from an array of CLLocationCoordinate2D
     - parameter coords: An array of CLLocationCoordinate2D
     - returns: An MKPolygon for direct reuse and set it in the class for future use
     */
    public func getPolygonWithCoordinates(_ coordinates: [CLLocationCoordinate2D]) -> MKPolygon {
        MKPolygon(coordinates: coordinates, count: coordinates.count)
    }

    /**
     Check if CLLocationCoordinate2D is inside a polygon
     - parameter coord: A CLLocationCoordinate2D variable
     - returns: A Boolean value, true if CLLocationCoordinate2D is in polygon, false if not
     */
    public func coordInPolygon(coord: CLLocationCoordinate2D) -> Bool {
        let mapPoint: MKMapPoint = MKMapPoint(coord)
        return self.pointInPolygon(mapPoint: mapPoint)
    }

    /**
     Check if MKMapPoint is inside a polygon
     - parameter mapPoint: An MKMapPoint variable
     - returns: A Boolean value, true if MKMapPoint is in polygon, false if not
     */
    public func pointInPolygon(mapPoint: MKMapPoint) -> Bool {
        let polygonRenderer: MKPolygonRenderer = MKPolygonRenderer(polygon: polygon)
        let polygonViewPoint: CGPoint = polygonRenderer.point(for: mapPoint)
        if polygonRenderer.path == nil {
            return false
        }
        return polygonRenderer.path.contains(polygonViewPoint)
    }

}
