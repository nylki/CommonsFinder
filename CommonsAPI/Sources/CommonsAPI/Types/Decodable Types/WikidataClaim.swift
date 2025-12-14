//
//  WikidataClaim.swift
//  CommonsAPI
//
//  Created by Tom Brewe on 16.01.25.
//

import Foundation
import os.log
import RegexBuilder
import CoreLocation

public typealias WikidataSnakValue = WikidataClaim.Snak.DataValue
public typealias WikidataItemID = WikidataSnakValue.WikiDataValueEntityID

public struct WikidataClaim: Codable, Hashable, Equatable, Sendable {
    public let mainsnak: Snak
    public let type: StatementType
    public let id: String?
    public let rank: Rank
    public let qualifiers: [WikidataProp: [Snak]]?
    
    public init(mainsnak: Snak, rank: Rank = .normal, qualifiers: [WikidataProp: [Snak]]? = nil) {
        self.mainsnak = mainsnak
        self.type = .statement
        self.rank = rank
        self.qualifiers = qualifiers
        self.id = nil
    }
    
    public enum StatementType: String, Codable, Sendable {
        case statement
        // TODO: could this be something else than statement?
    }
    public enum Rank: String, Codable, Sendable {
        case normal
        case preferred
        case deprecated
    }
    
    public struct Snak: Codable, Equatable, Hashable, Sendable {
        public let snaktype: String
        public let property: WikidataProp
        public let hash: String?
        public let datavalue: DataValue?
        
//        public enum DataType: String, Sendable, Codable {
//            case wikibaseItem = "wikibase-item"
//            case externalId = "external-id"
//            case url
//        }

        
        public init(snaktype: String, property: WikidataProp, datavalue: DataValue?) {
            self.snaktype = snaktype
            self.property = property
            self.datavalue = datavalue
            self.hash = nil
//            self.datatype = datatype
        }
        
        public enum DataValue: Codable, Equatable, Hashable, Sendable {
            case wikibaseEntityID(WikiDataValueEntityID)
            case time(WikiDataValueTime)
            case string(String)
            case quantity(Quantity)
            case globecoordinate(Coordinate)
            case monolingualtext
            
            
            private enum CodingKeys: CodingKey {
                case type
                case value
            }

            public struct Quantity: Codable, Equatable, Hashable, Sendable {
                // check if we can directly use double instead?
                private let amount: String
                private let variance: String?
                public let unit: String
                
                public var amountNumber: Double {
                    Double(amount) ?? .nan
                }
                
                public init(amount: Double, unit: URL?) {
                    self.amount = String(amount)
                    self.variance = nil
                    self.unit = unit?.absoluteString ?? "1"
                }
                
                public init(amount: Int, unit: URL?) {
                    self.amount = String(amount)
                    self.variance = nil
                    self.unit = unit?.absoluteString ?? "1"
                }
            }
            
            public struct Coordinate: Codable, Equatable, Hashable, Sendable {
                public let latitude: CLLocationDegrees
                public let longitude: CLLocationDegrees
                public let altitude: Double?
                public let precision: CLLocationDegrees?
                public let globe: URL
                
                public init(latitude: CLLocationDegrees, longitude: CLLocationDegrees, altitude: Double?, precision: CLLocationDegrees?, globe: URL) {
                    self.latitude = latitude
                    self.longitude = longitude
                    self.altitude = altitude
                    self.precision = precision
                    self.globe = globe
                }
            }
            

            
            /// the Q-Item ID (or can there be other types?)
            public struct WikiDataValueEntityID: Codable, Sendable, Equatable, Hashable {
                public let id: String // eg. Q50423863
                public let entityType: String
                public let numericID: Int // eg. 50423863
                
                enum CodingKeys: String, CodingKey {
                    case id
                    case entityType = "entity-type"
                    case numericID = "numeric-id"
                }
            }
            
            
            public init(from decoder: any Decoder) throws {
                do {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    // First check the type then attempt to decode the associated value
                    let type = try container.decode(String.self, forKey: .type)
                    
                    switch type {
                    case "wikibase-entityid":
                        let value: WikiDataValueEntityID = try container.decode(WikiDataValueEntityID.self, forKey: .value)
                        self = .wikibaseEntityID(value)
                    case "time":
                        let value: WikiDataValueTime = try container.decode(WikiDataValueTime.self, forKey: .value)
                        self = .time(value)
                    case "string":
                        let value: String = try container.decode(String.self, forKey: .value)
                        self = .string(value)
                    case "quantity":
                        let value = try container.decode(Quantity.self, forKey: .value)
                        self = .quantity(value)
                    case "globecoordinate":
                        let value = try container.decode(Coordinate.self, forKey: .value)
                        self = .globecoordinate(value)
                    case "monolingualtext":
                        self = .monolingualtext
                    default:
                        throw CommonsAPIDecodingError.needsImplementation(type)
                    }
                } catch {
                    Logger().error("Failed to decode DataValue \(error)")
                    throw error
                }
            }
            
            public func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                switch self {
                case .wikibaseEntityID(let id):
                    try container.encode("wikibase-entityid", forKey: .type)
                    // FIXME could this theoretically not be a Q-Item but something else?
                    try container.encode(id, forKey: .value)
                case .time(let time):
                    try container.encode("time", forKey: .type)
                    try container.encode(time, forKey: .value)
                case .string(let string):
                    try container.encode("string", forKey: .type)
                    try container.encode(string, forKey: .value)
                case .quantity(let quantity):
                    do {
                        try container.encode("quantity", forKey: .type)
                        try container.encode(quantity, forKey: .value)
                    } catch {
                        Logger().error("Failed to encode quantity \(error)")
//                        throw error
                    }
                case .globecoordinate(let coordinate):
                    try container.encode("globecoordinate", forKey: .type)
                    try container.encode(coordinate, forKey: .value)
                case .monolingualtext:
                    try container.encode("monolingualtext", forKey: .type)
                }
            }
        }
    }
}

// MARK: Time and Date

public struct WikiDataValueTime: Codable, Equatable, Hashable, Sendable {
    let time: String
    let timezone: Int
    let before: Int
    let after: Int
    let precision: Int
    let calendarmodel: URL
    
    // TODO: cache Date on init if it is a standard gregorian date?
}

extension WikiDataValueTime {
    // see: https://www.wikidata.org/wiki/Help:Dates
//    Quote:
//    > That is an accurate description of the saved structure; however, much of it is not being used at the moment:
//
//    > time field can not be saved with precision higher than a "day".
//    > We do not use before and after fields and use qualifiers instead to indicate time period.
//    > timezone is also not used the encoding (Z) suggest UTC timezone (the date in London), but general practice on Wikidata is to save dates as reported in literature, which usually means   > in local timezone.
//    > calendar – explicit value defining calendar model. Currently two calendar models are supported: proleptic Gregorian calendar (Q1985727) and proleptic Julian calendar (Q1985786)
    
    // list of time-of-day for refine-data: http://www.wikidata.org/entity/Wikidata:WikiProject_Calendar_Dates/lists/time_of_the_day
    
    /// the given ISO-Date is not checked, make sure it actually is an ISO date
    public init(isoDate: String) {
        self = .init(
            time: isoDate,
            timezone: 0,
            before: 0,
            after: 0,
            precision: 11, // NOTE: only precisionm 11 (day) is valid, see above
            calendarmodel: URL(string: "http://www.wikidata.org/entity/Q1985727")!
        )
    }

    public init(date: Date, timezone: TimeZone) {
        self = .init(
            time: date.ISO8601Format(.iso8601Date(timeZone: timezone).time(includingFractionalSeconds: false).timeSeparator(.colon).timeZone(separator: .omitted)),
            timezone: 0,
            before: 0,
            after: 0,
            precision: 11, // TODO: ok here it gets a complicated, apparently only precision 11 (day) works because of Wikidata limits.
            // would have to use qualifiers for the time and timezone.
            calendarmodel: URL(string: "http://www.wikidata.org/entity/Q1985727")!
        )
    }
    
    public var dateString: String { time }
    
    /// **Returns the day only**, the time is not encoded here (see code comments)
    public var date: Date? {
        if calendarmodel.lastPathComponent == "Q1985727" {
            // NOTE: Wikidata is not ISO8601 compliant and adds a "+"-prefix in years between 0-9999
            // so we normalize them here and strip the "+", to be able to parse the string
            // with standard Swift Date-methods.
            guard let normalizedISOString = time.split(separator: "+").first else {
                return nil
            }
            let withoutFractionalSeconds = try? Date(normalizedISOString, strategy: .iso8601.year().month().day().dateSeparator(.dash))
            return withoutFractionalSeconds
        } else {
            return nil
        }
    }
}


extension WikidataClaim.Snak.DataValue.WikiDataValueEntityID {
    public static func Q(_ numericID: Int) -> Self {
        Self(id: "Q\(numericID)", entityType: "item", numericID: numericID)
    }
    
    /// Initialize with a Q-ID string, eg. "Q2"
    public init?(stringValue: String) {
        let split = stringValue.split(separator: "Q")
        guard let numericID = Int(split[0]) else {
            return nil
        }
        self.init(id: stringValue, entityType: "item", numericID: numericID)
    }
}

extension WikidataClaim.Snak.DataValue.Quantity {
    /// Q-Item ID
    public var unitID: WikidataClaim.Snak.DataValue.WikiDataValueEntityID? {
        if unit != "1" {
            guard let id = URL(string: unit)?.lastPathComponent, id.starts(with: "Q") else {
                assertionFailure("a unit is expected to always be a url of a Q-item. this one: \(unit)")
                return nil
            }
            return .init(stringValue: id)
        } else {
            return nil
        }
    }
}

// MARK: Wikidata Prop (eg. P160)

public struct WikidataProp: Hashable, Equatable, Sendable, Codable, RawRepresentable {
    public let intValue: Int
    public var rawValue: String {
        "P\(intValue)"
    }
    
    public init(intValue: Int) {
        self.intValue = intValue
    }
    
    public init?(rawValue: String) {
        let numberRef = Reference(Int.self)
        let regex = Regex {
            "P"
            TryCapture(as: numberRef) {
                OneOrMore(.digit)
            }  transform: { match in
                Int(match)
            }
            
        }
        guard let match = rawValue.firstMatch(of: regex) else {
            return nil
        }
        intValue = match[numberRef]
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        if let value = WikidataProp.init(rawValue: string) {
            self = value
        } else {
            throw CommonsAPIDecodingError.failedToDecodeWikidataProp
        }
        
    }
}

extension WikidataProp: CodingKeyRepresentable {
    public var codingKey: CodingKey {
        AnyCodingKey(stringValue: rawValue)!
    }
    
    public init?<T>(codingKey: T) where T : CodingKey {
        self.init(rawValue: codingKey.stringValue)
    }
}

extension WikidataProp: CustomStringConvertible {
    public var description: String { rawValue }
}

private struct AnyCodingKey: CodingKey {
    let stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {  self.stringValue = stringValue  }
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
extension WikidataClaim.Snak.DataValue.WikiDataValueEntityID {
    /// Q1
    /// http://www.wikidata.org/entity/Q1
    public static var universe: Self { .Q(1) }
    
    /// Q2
    /// http://www.wikidata.org/entity/Q2
    public static var earth: Self { .Q(2) }
    
    /// Q1457258 (not the main physics item, but the item for the commons category "physics")
    /// http://www.wikidata.org/entity/Q1457258
    public static var physicsCategory: Self { .Q(1457258) }
    
    /// Q50423863
    /// http://www.wikidata.org/entity/Q50423863
    public static var copyrighted: Self { .Q(50423863) }
    
    /// Q88088423
    /// http://www.wikidata.org/entity/Q88088423
    public static var copyrightedDedicatedToThePublicDomainByCopyrightHolder: Self { .Q(88088423) }
    
    /// Q19652
    /// http://www.wikidata.org/entity/Q19652
    public static var publicDomainCopyrightStatus: Self { .Q(19652) }
    
    
    // Licenses
    public static var CC0: Self { .Q(6938433) }
    public static var PDM_1_0: Self { .Q(7257361) }
    public static var publicDomainLicense: Self { .Q(98592850) }
    public static var CC_BY_4_0: Self { .Q(20007257) }
    public static var CC_BY_3_0: Self { .Q(14947546) }
    public static var CC_BY_IGO_3_0: Self { .Q(26259495) }
    public static var CC_BY_2_5: Self { .Q(18810333) }
    public static var CC_BY_1_0: Self { .Q(30942811) }
    public static var CC_BY_2_0: Self { .Q(19125117) }
    public static var CC_BY_SA_4_0: Self { .Q(18199165) }
    public static var CC_BY_SA_3_0: Self { .Q(14946043) }
    public static var CC_BY_SA_IGO_3_0: Self { .Q(56292840) }
    public static var CC_BY_SA_2_5: Self { .Q(19113751) }
    public static var CC_BY_SA_2_0: Self { .Q(19068220) }
    public static var CC_BY_SA_1_0: Self { .Q(47001652) }
     
     /// Q66458942 (used for source)
     /// http://www.wikidata.org/entity/Q66458942
     public static var originalCreationByUploader: Self { .Q(66458942) }
     
     /// Q13414952
     /// http://www.wikidata.org/entity/Q13414952
     public static var sha1: Self { .Q(13414952) }
     
     
     
}

// most used props on commons: https://commons.wikimedia.org/wiki/Commons:Structured_data/Properties_table
// all available props: http://www.wikidata.org/wiki/Wikidata:Database_reports/List_of_properties/all
public extension WikidataProp {
    /// P180
    /// http://www.wikidata.org/entity/P180
    static var depicts: Self { .init(intValue: 180) }
    
    /// P180
    /// http://www.wikidata.org/entity/P571
    static var inception: Self { .init(intValue: 571) }
    
    /// P4241
    /// http://www.wikidata.org/entity/P4241
    static var refineDate: Self { .init(intValue: 4241) }
    
    /// P421
    /// http://www.wikidata.org/entity/P421
    static var timezone: Self { .init(intValue: 421) }
    
    /// P1259
    /// http://www.wikidata.org/entity/P1259
    static var coordinatesOfViewpoint: Self { .init(intValue: 1259) }
    
    /// P7787
    /// http://www.wikidata.org/entity/P7787
    static var heading: Self { .init(intValue: 7787) }
    
    /// P7482
    /// http://www.wikidata.org/entity/P7482
    static var source: Self { .init(intValue: 7482) }
    
    /// P6216
    /// http://www.wikidata.org/entity/P6216
    static var copyrightStatus: Self { .init(intValue: 6216) }
    
    /// P170
    /// http://www.wikidata.org/entity/P170
    static var creator: Self { .init(intValue: 170) }
    
    /// P2093
    /// http://www.wikidata.org/entity/P2093
    static var authorNameString: Self { .init(intValue: 2093) }
    
    /// P4174
    /// http://www.wikidata.org/entity/P4174
    static var wikimediaUsername: Self { .init(intValue: 4174) }
    
    /// P2699
    /// http://www.wikidata.org/entity/P2699
    static var url: Self { .init(intValue: 2699) }
    
    /// P275
    /// http://www.wikidata.org/entity/P275
    static var license: Self { .init(intValue: 275) }
    
    /// P1163
    /// http://www.wikidata.org/entity/P1163
    static var mimeType: Self { .init(intValue: 1163) }
    
    /// P3575
    /// http://www.wikidata.org/entity/P3575
    static var dataSize: Self { .init(intValue: 3575) }
    
    /// P2049
    /// http://www.wikidata.org/entity/P2049
    static var width: Self { .init(intValue: 2049) }
    
    /// P2048
    /// http://www.wikidata.org/entity/P2048
    static var height: Self { .init(intValue: 2048) }
    
    /// P4092
    /// http://www.wikidata.org/entity/P4092
    static var checksum: Self { .init(intValue: 4092) }
    
    /// P459
    /// http://www.wikidata.org/entity/P459
    static var determinationMethodOrStandard: Self { .init(intValue: 459) }
    
    /// P6757
    /// http://www.wikidata.org/entity/P6757
    static var exposureTime: Self { .init(intValue: 6757) }
    
    /// P6790
    /// http://www.wikidata.org/entity/P6790
    static var fnumber: Self { .init(intValue: 6790) }
    
    /// P6789
    /// http://www.wikidata.org/entity/P6789
    static var isoSpeed: Self { .init(intValue: 6789) }
    
    /// P2151
    /// http://www.wikidata.org/entity/P2151
    static var focalLength: Self { .init(intValue: 2151) }
    
    /// P31
    /// http://www.wikidata.org/entity/P31
    static var instanceOf: Self { .init(intValue: 31) }
}

extension WikidataClaim {
    public init(property: WikidataProp, item: WikidataItemID?, qualifiers: [WikidataProp: [Snak]]? = nil) {
        let snak: Snak = if let item {
            Snak(
                snaktype: "value",
                property: property,
                datavalue: .wikibaseEntityID(.Q(item.numericID))
            )
        } else {
            Snak(
                snaktype: "somevalue",
                property: property,
                datavalue: nil
            )
        }

        self.init(mainsnak: snak, qualifiers: qualifiers)
    }
    

    
    public init(property: WikidataProp, quantity: WikidataSnakValue.Quantity) {
        let snak = Snak(
            snaktype: "value",
            property: property,
            datavalue: .quantity(quantity)
        )
        self.init(mainsnak: snak)
    }
    
    public init(property: WikidataProp, string: String, qualifiers: [WikidataProp: [Snak]]? = nil) {
        let snak = Snak(
            snaktype: "value",
            property: property,
            datavalue: .string(string)
        )
        self.init(mainsnak: snak, qualifiers: qualifiers)
    }
    
    public init(property: WikidataProp, coordinate: WikidataSnakValue.Coordinate, qualifiers: [WikidataProp: [Snak]]? = nil) {
        let snak = Snak(
            snaktype: "value",
            property: property,
            datavalue: .globecoordinate(coordinate)
        )
        self.init(mainsnak: snak, qualifiers: qualifiers)
    }
    
    public init(property: WikidataProp, isoDateString: String) {
        let snak = Snak(
            snaktype: "value",
            property: property,
            datavalue: .time(.init(isoDate: isoDateString))
        )
        self.init(
            mainsnak: snak, rank: .normal,
            qualifiers: [
                :
                    //            .refineDate: [.init(snaktype: "value", property: .refineDate, datavalue: .wikibaseEntityID())],
                //            .timezone: [.init(snaktype: "value", property: .timezone, datavalue: .wikibaseEntityID())]
            ])
    }
    
    
    /// P180
    public static func depicts(_ itemID: WikidataItemID) -> WikidataClaim {
        WikidataClaim(property: .depicts, item: itemID)
    }
    /// P571 (aka 'inception')
    /// can be used to initialize a fully qualified date (with refine-date and timezone qualifiers)
    public static func inception(_ isoDateString: String) -> WikidataClaim {
        WikidataClaim(property: .inception, isoDateString: isoDateString)
    }
    
    public static func refineDate(_ itemID: WikidataItemID) -> WikidataClaim {
        WikidataClaim(property: .refineDate, item: itemID)
    }
    
    public static func timezone(_ itemID: WikidataItemID) -> WikidataClaim {
        WikidataClaim(property: .timezone, item: itemID)
    }
    
    public static func coordinatesOfViewpoint(_ coordinate: CLLocationCoordinate2D, altitude: Double, precision: CLLocationDegrees, heading: Double?) -> WikidataClaim {
        var qualifiers: [WikidataProp: [Snak]]? = nil
        if let heading {
            let headingSnak = Snak(
                snaktype: "value",
                property: .heading,
                datavalue: .quantity(
                    .init(
                        amount: heading,
                        unit: URL(string: "http://www.wikidata.org/entity/Q28390")!)
                )
            )
            qualifiers = [.heading: [headingSnak]]
        }
        
        return WikidataClaim(
            property: .coordinatesOfViewpoint,
            coordinate: .init(coordinate: coordinate, altitude: altitude, precision: precision),
            qualifiers: qualifiers
        )
    }
    
    public static func heading(_ itemID: WikidataItemID) -> WikidataClaim {
        WikidataClaim(property: .heading, item: itemID)
    }
    
    public static func license(_ itemID: WikidataItemID) -> WikidataClaim {
        WikidataClaim(property: .license, item: itemID)
    }
    
    public static func copyrightStatus(_ itemID: WikidataItemID) -> WikidataClaim {
        WikidataClaim(property: .copyrightStatus, item: itemID)
    }
    
    /// The authorNameString and wikimediaUsername are often the same, but are allowed to differ
    /// eg. full name for authorNameString but nickname for username,
    // https://commons.wikimedia.org/wiki/Commons:Structured_data/Modeling/Author
    public static func creator(wikimediaUsername: String?, authorNameString: String?, url: String?) -> WikidataClaim {
        var qualifiers: [WikidataProp: [Snak]] = .init()
        
        if let wikimediaUsername {
            let wikimediaUsernameSnak = Snak(snaktype: "value", property: .wikimediaUsername, datavalue: .string(wikimediaUsername))
            qualifiers[.wikimediaUsername] = [wikimediaUsernameSnak]
        }
        
        if let url {
            let urlSnak = Snak(snaktype: "value", property: .url, datavalue: .string(url))
            qualifiers[.url] = [urlSnak]
        }
        
        if let authorNameString {
            let authorNameStringSnak = Snak(snaktype: "value", property: .authorNameString, datavalue: .string(authorNameString))
            qualifiers[.authorNameString] = [authorNameStringSnak]
        }
        
        return WikidataClaim(property: .creator, item: nil, qualifiers: qualifiers)
    }
    
    public static func creator(_ itemID: WikidataItemID) -> WikidataClaim {
        WikidataClaim(property: .creator, item: itemID)
    }
    
    public static func source(_ itemID: WikidataItemID) -> WikidataClaim {
        WikidataClaim(property: .source, item: itemID)
    }
    
    public static func source(_ url: String) -> WikidataClaim {
        WikidataClaim(property: .source, string: url)
    }
    
    public static func mimeType(_ mimeType: String) -> WikidataClaim {
        WikidataClaim(property: .mimeType, string: mimeType)
    }
    
    public static func sha1Checksum(_ sha1: String) -> WikidataClaim {
        var qualifiers: [WikidataProp: [Snak]] = .init()
        qualifiers[.determinationMethodOrStandard] = [Snak(snaktype: "value", property: .determinationMethodOrStandard, datavalue: .wikibaseEntityID(.sha1))]
        return WikidataClaim(property: .checksum, string: sha1, qualifiers: qualifiers)
    }
    
    public static func dataSize(_ byte: Int64) -> WikidataClaim {
        WikidataClaim(property: .dataSize, quantity: .init(amount: Int(byte), unit: .init(string: "http://www.wikidata.org/entity/Q8799")!))
    }
    
    public static func width(_ pixel: Int) -> WikidataClaim {
        WikidataClaim(property: .width, quantity: .init(amount: pixel, unit: .init(string: "http://www.wikidata.org/entity/Q355198")!))
    }
    
    public static func height(_ pixel: Int) -> WikidataClaim {
        WikidataClaim(property: .height, quantity: .init(amount: pixel, unit: .init(string: "http://www.wikidata.org/entity/Q355198")!))
    }
    
    public static func determinationMethodOrStandard(_ itemID: WikidataItemID) -> WikidataClaim {
        WikidataClaim(property: .determinationMethodOrStandard, item: itemID)
    }
    
    public static func exposureTime(_ seconds: Double) -> WikidataClaim {
        WikidataClaim(property: .exposureTime, quantity: .init(amount: seconds, unit: .init(string: "http://www.wikidata.org/entity/Q11574")!))
    }
    
    public static func fnumber(_ value: Double) -> WikidataClaim {
        WikidataClaim(property: .fnumber, quantity: .init(amount: value, unit: nil))
    }
    
    public static func isoSpeed(_ value: Int) -> WikidataClaim {
        WikidataClaim(property: .isoSpeed, quantity: .init(amount: value, unit: nil))
    }
    
    public static func focalLength(_ mm: Double) -> WikidataClaim {
        WikidataClaim(property: .focalLength, quantity: .init(amount: mm, unit: .init(string: "http://www.wikidata.org/entity/Q174789")!))
    }
    
    public static func instanceOf(_ itemID: WikidataItemID) -> WikidataClaim {
        WikidataClaim(property: .instanceOf, item: itemID)
    }
    
    
    public var mainProp: WikidataProp { mainsnak.property }
    
    public var isDepicts: Bool { mainProp == .depicts }
    public var isLicense: Bool { mainProp == .license }
    public var isCopyrightStatus: Bool { mainProp == .copyrightStatus }
    public var isInception: Bool { mainProp == .inception }
    public var isCoordinatesOfViewPoint: Bool { mainProp == .coordinatesOfViewpoint }
    
    // contains a Q-Item if the statement `value` is of type entity, otherwise (eg. quantity, time) nil
    public var mainItem: WikidataItemID? {
        if case .wikibaseEntityID(let itemID) = mainsnak.datavalue {
            itemID
        } else {
            nil
        }
    }
}

extension WikidataClaim.Snak.DataValue.Coordinate {
    public init(coordinate: CLLocationCoordinate2D, altitude: Double, precision: CLLocationDegrees) {
        self.init(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            altitude: altitude,
            precision: precision,
            // A CLLocation is a geo-reference on earth, so its save to assume Q2 (Earth) here.
            globe: URL(string: "http://www.wikidata.org/entity/Q2")!
        )
    }
}
