//
//  CLLocation+gpsDictionary.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 22.04.25.
//

import CoreLocation
import ImageIO

extension CLLocation {
    var gpsDictionary: [String: Any] {
        var gps = [String: Any]()

        let timeFormatter = DateFormatter()
        timeFormatter.timeZone = .gmt
        timeFormatter.dateFormat = "HH:mm:ss.SS"

        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = .gmt
        dateFormatter.dateFormat = "yyyy:MM:dd"


        gps[kCGImagePropertyGPSLatitude as String] = abs(coordinate.latitude)
        gps[kCGImagePropertyGPSLatitudeRef as String] = coordinate.latitude >= 0 ? "N" : "S"
        gps[kCGImagePropertyGPSLongitude as String] = abs(coordinate.longitude)
        gps[kCGImagePropertyGPSLongitudeRef as String] = coordinate.longitude >= 0 ? "E" : "W"
        gps[kCGImagePropertyGPSAltitude as String] = altitude
        gps[kCGImagePropertyGPSDateStamp as String] = dateFormatter.string(from: timestamp)
        gps[kCGImagePropertyGPSTimeStamp as String] = timeFormatter.string(from: timestamp)

        return gps
    }
}
