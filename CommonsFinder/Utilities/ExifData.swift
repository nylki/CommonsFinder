//
//  ExifData.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 28.12.24.
//

import CoreLocation
import Foundation
import ImageIO
import os.log

enum ExifExtractionError: Error {
    case failedToReadExif
}

// Adapted from https://gist.github.com/lukebrandonfarrell/961a6dbc8367f0ac9cabc89b0052d1fe
nonisolated struct ExifData: Codable, Equatable, Hashable {
    enum Orientation: Int, Codable {
        case horizontal = 1
        case MirrorHorizontal = 2
        case rotate180 = 3
        case mirrorVertical = 4
        case MirrorHorizontalAndRotate270CW = 5
        case Rotate90CW = 6
        case MirrorHorizontalAndRotate90CW = 7
        case Rotate270CW = 8

        /// 90 degrees rotated
        var widthHeightFlipped: Bool {
            switch self {
            case .horizontal, .MirrorHorizontal, .rotate180, .mirrorVertical:
                false
            case .MirrorHorizontalAndRotate270CW, .Rotate90CW, .MirrorHorizontalAndRotate90CW, .Rotate270CW:
                true
            }
        }
    }

    private(set) var colorModel: String?

    private var pixelWidth: Int?
    private var pixelHeight: Int?

    var normalizedWidth: Int? {
        guard let pixelWidth, let pixelHeight else { return nil }
        return if let orientation, orientation.widthHeightFlipped {
            pixelHeight
        } else {
            pixelWidth
        }
    }

    var normalizedHeight: Int? {
        guard let pixelWidth, let pixelHeight else { return nil }
        return if let orientation, orientation.widthHeightFlipped {
            pixelWidth
        } else {
            pixelHeight
        }
    }

    private(set) var dpiWidth: Int?
    private(set) var dpiHeight: Int?
    private(set) var depth: Int?
    private(set) var orientation: Orientation?
    private(set) var subjectArea: CGRect?

    private(set) var apertureValue: String?
    private(set) var brightnessValue: String?

    private(set) var fNumber: Double?
    private(set) var isoSpeedRatings: [Int]?
    private(set) var exposureTime: Double?

    private(set) var lensModel: String?
    private(set) var lensMake: String?

    private(set) var dateTimeDigitized: String?
    private(set) var dateTimeOriginal: String?
    private(set) var offsetTime: String?
    private(set) var offsetTimeDigitized: String?
    private(set) var offsetTimeOriginal: String?

    private(set) var model: String?
    private(set) var software: String?

    private(set) var tileLength: Double?
    private(set) var tileWidth: Double?
    private(set) var xResolution: Double?
    private(set) var yResolution: Double?

    private(set) var imgDirection: Double?
    private(set) var altitude: Double?
    /// see discussion: https://exiftool.org/forum/index.php?topic=15654.0
    /// and test with front/back cam for accuracy of angle
    private var destBearing: Double?

    var normalizedBearing: Double? {
        if let destBearing {
            GeoVectorMath.normalizeBearing(degrees: destBearing)
        } else {
            nil
        }
    }

    /// positioning error in meters
    private(set) var hPositioningError: Double?
    private(set) var gpsDOP: Double?

    private(set) var latitude: Double?
    private(set) var longitude: Double?
    private(set) var speed: Double?


    private(set) var gpsTimestamp: String?
    private(set) var gpsDatestamp: String?
    // Combined from both above
    private(set) var gpsDate: Date?

    var coordinate: CLLocationCoordinate2D? {
        if let latitude, let longitude {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        } else {
            nil
        }
    }

    var dateOriginal: Date? {
        guard let dateOriginalISOString else { return nil }

        do {
            return try Date(
                "\(dateOriginalISOString)",
                strategy: .iso8601.year().month().day().time(includingFractionalSeconds: false).timeSeparator(.colon).timeZone(separator: .omitted)
            )
        } catch {
            logger.warning("Failed to parse Date! \(error)")
            return nil
        }

    }

    private var dateOriginalISOString: String? {
        guard let dateTimeOriginal else { return nil }
        let components = dateTimeOriginal.split(separator: " ")
        guard components.count == 2 else { return nil }
        let dateComponent = components[0].replacing(":", with: "-")
        let timeComponent = components[1]
        var timezoneOffset = ""
        timezoneOffset = offsetTimeOriginal ?? "Z"
        return "\(dateComponent)T\(timeComponent)\(timezoneOffset)"
    }

    /// This is an ISO-8601 Date String that only correcly encodes the date component
    /// all time components are set to 0, the timezone is _incorrectly_ set to UTC (Z).
    /// Unfortunately this format is required for Wikidata dates.
    /// eg: +2025-01-19T00:00:00Z instead of +2025-01-19T20:21:22Z
    /// see: timezoneOffset
    var dateOnlyWikidataCompatibleISOString: String? {
        guard let dateTimeOriginal else { return nil }
        let components = dateTimeOriginal.split(separator: " ")
        guard let dateComponent = components.first?.replacing(":", with: "-") else {
            return nil
        }

        let timezoneOffset = "Z"
        return "+\(dateComponent)T00:00:00\(timezoneOffset)"
    }


    init(data: Data) throws {
        try self.init(cfData: data as CFData)
    }

    init(url: URL) throws {
        let data = try Data(contentsOf: url)
        try self.init(data: data)
    }


    private init(cfData: CFData) throws {
        let options = [kCGImageSourceShouldCache as String: kCFBooleanFalse]
        guard let imgSrc = CGImageSourceCreateWithData(cfData, options as CFDictionary),
            let rawMetadata = CGImageSourceCopyPropertiesAtIndex(imgSrc, 0, options as CFDictionary)
        else {
            throw ExifExtractionError.failedToReadExif
        }

        let metadata = rawMetadata as NSDictionary

        self.colorModel = metadata[kCGImagePropertyColorModel] as? String
        self.pixelWidth = metadata[kCGImagePropertyPixelWidth] as? Int
        self.pixelHeight = metadata[kCGImagePropertyPixelHeight] as? Int
        self.dpiWidth = metadata[kCGImagePropertyDPIWidth] as? Int
        self.dpiHeight = metadata[kCGImagePropertyDPIHeight] as? Int
        self.depth = metadata[kCGImagePropertyDepth] as? Int
        if let rawOrientation = metadata[kCGImagePropertyOrientation] as? Int {
            self.orientation = .init(rawValue: rawOrientation)
        }

        if let tiffData = metadata[kCGImagePropertyTIFFDictionary] as? NSDictionary {
            self.model = tiffData[kCGImagePropertyTIFFModel] as? String
            self.software = tiffData[kCGImagePropertyTIFFSoftware] as? String
            self.tileLength = tiffData[kCGImagePropertyTIFFTileLength] as? Double
            self.tileWidth = tiffData[kCGImagePropertyTIFFTileWidth] as? Double
            self.xResolution = tiffData[kCGImagePropertyTIFFXResolution] as? Double
            self.yResolution = tiffData[kCGImagePropertyTIFFYResolution] as? Double
        }

        if let exifData = metadata[kCGImagePropertyExifDictionary] as? NSDictionary {
            self.apertureValue = exifData[kCGImagePropertyExifApertureValue] as? String
            self.brightnessValue = exifData[kCGImagePropertyExifBrightnessValue] as? String
            self.dateTimeDigitized = exifData[kCGImagePropertyExifDateTimeDigitized] as? String
            self.dateTimeOriginal = exifData[kCGImagePropertyExifDateTimeOriginal] as? String
            self.offsetTime = exifData[kCGImagePropertyExifOffsetTime] as? String
            self.offsetTimeDigitized = exifData[kCGImagePropertyExifOffsetTimeDigitized] as? String
            self.offsetTimeOriginal = exifData[kCGImagePropertyExifOffsetTimeOriginal] as? String
            self.exposureTime = exifData[kCGImagePropertyExifExposureTime] as? Double
            self.lensMake = exifData[kCGImagePropertyExifLensMake] as? String
            self.lensModel = exifData[kCGImagePropertyExifLensModel] as? String
            self.fNumber = exifData[kCGImagePropertyExifFNumber] as? Double
            self.isoSpeedRatings = exifData[kCGImagePropertyExifISOSpeedRatings] as? [Int]
            if let subjectArea = exifData[kCGImagePropertyExifSubjectArea] as? [Int] {
                self.subjectArea = CGRect(
                    x: subjectArea[0],
                    y: subjectArea[1],
                    width: subjectArea[2],
                    height: subjectArea[3]
                )
            }
        }

        if let gpsData = metadata[kCGImagePropertyGPSDictionary] as? NSDictionary {
            self.altitude = gpsData[kCGImagePropertyGPSAltitude] as? Double
            self.destBearing = gpsData[kCGImagePropertyGPSDestBearing] as? Double

            // TODO: in meters, set accurac
            self.hPositioningError = gpsData[kCGImagePropertyGPSHPositioningError] as? Double

            self.gpsDOP = gpsData[kCGImagePropertyGPSDOP] as? Double
            self.imgDirection = gpsData[kCGImagePropertyGPSImgDirection] as? Double

            self.gpsTimestamp = gpsData[kCGImagePropertyGPSTimeStamp] as? String
            self.gpsDatestamp = gpsData[kCGImagePropertyGPSDateStamp] as? String
            if let gpsDatestamp, let gpsTimestamp {
                let normalizedDate = String(gpsDatestamp.replacing(":", with: "-"))
                self.gpsDate = try? .init(
                    "\(normalizedDate)T\(gpsTimestamp)",
                    strategy: .iso8601.year().month().day().time(includingFractionalSeconds: false).timeSeparator(.colon)
                )
            }

            if let latitude = gpsData[kCGImagePropertyGPSLatitude] as? Double {
                if let latitudeRef = gpsData[kCGImagePropertyGPSLongitudeRef] as? String,
                    latitudeRef == "S",
                    latitude > 0
                {
                    self.latitude = -latitude
                } else {
                    self.latitude = latitude
                }
            }

            if let longitude = gpsData[kCGImagePropertyGPSLongitude] as? Double {
                if let longitudeRef = gpsData[kCGImagePropertyGPSLongitudeRef] as? String,
                    longitudeRef == "W",
                    longitude > 0
                {
                    self.longitude = -longitude
                } else {
                    self.longitude = longitude
                }
            }
            self.speed = gpsData[kCGImagePropertyGPSSpeed] as? Double
        }
    }
}
