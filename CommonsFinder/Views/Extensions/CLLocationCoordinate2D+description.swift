//
//  CLLocationCoordinate2D+description.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 01.05.26.
//

import CoreLocation

extension CLLocationCoordinate2D: @retroactive CustomStringConvertible {
    public var description: String {
        let latSign = latitude.sign == .minus ? "-" : ""
        let lonSign = longitude.sign == .minus ? "-" : ""
        return "\(latSign)\(latitude), \(lonSign)\(longitude)"
    }
}
