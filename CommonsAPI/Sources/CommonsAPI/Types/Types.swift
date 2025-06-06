//
//  Types.swift
//  CommonsAPI
//
//  Created by Tom Brewe on 28.09.24.
//

import Foundation
import os.log
@preconcurrency import RegexBuilder
import CoreLocation

// MARK: - Public Types

public enum CommonsAPIDecodingError: Error {
    case failedToDecodeImageInfoSingleValueArray
    case failedToDecodeWikidataProp
    case needsImplementation(String)
    case quantityDecodingError(String)
}

public struct LanguageString: Codable, Equatable, Hashable, Sendable {
    public typealias LanguageCode = String
    public var string: String
    public var languageCode: LanguageCode
}

public extension LanguageString {
    init(_ string: String, languageCode: LanguageCode) {
        self.languageCode = languageCode
        self.string = string
    }
    
    init(languageCode: LanguageCode) {
        self.languageCode = languageCode
        self.string = ""
    }
}

public enum ListDirection: String {
    case older
    case newer
}


public enum ListLimit: Sendable {
    case max
    case count(Int)
    
    var apiString: String {
        switch self {
        case .max: "max"
        case .count(let count):
            String(count)
        }
    }
    
}

public enum AuthStatus: String, Decodable, Sendable {
    /// PASS: the operation succeded
    case pass = "PASS"
    /// FAIL: the operation failed
    case fail = "FAIL"
    /// UI: requires additional input from user, ie. 2-factor.
    /// From the API docs: present the new fields to the user and obtain their submission. Then post to this module with logincontinue and the relevant fields set
    case ui = "UI"
    /// REDIRECT: direct the user to the redirecttarget and wait for the return to loginreturnurl. Then post again with `logincontinue` param and any fields passed to the return URL, and repeat the login.
    /// see: https://commons.wikimedia.org/w/api.php?action=help&modules=clientlogin
    case redirect = "REDIRECT"
    /// RESTART: the authentication worked but we don't have a linked user account. You might treat this as `ui` or as `fail`.
    case restart = "RESTART"
}

public enum UploadStatus: Sendable, Equatable, Hashable {

    /// Step 1: file is uploaded to the stash first (will be unstashed in Step 3.)
    case uploadingFile(Progress)
    /// Step 2
    case creatingWikidataClaims
    /// Step 3
    case unstashingFile
    // Step 4: the file is published and visible online
    case published
    case uploadWarnings([FileUploadResponse.Warning])
    case unspecifiedError(String)
    
    var isError: Bool {
        if case .uploadWarnings(_) = self { true } else { false }
    }
    
}

public struct FileUploadResponse: Decodable, Sendable {
    public let upload: Upload

    public enum Warning: Error, Decodable, Equatable, Hashable, Sendable, CustomStringConvertible {
        case exists(description: String)
        case existsNormalized(description: String)
        case wasDeleted(description: String)
        case duplicate(description: String)
        case duplicateArchive(description: String)
        case badfilename(description: String)
        
        public var description: String {
            switch self {
            case let .exists(description): "exists: \(description)"
            case let .existsNormalized(description): "exists-normalized: \(description)"
            case let .wasDeleted(description): "wasDeleted: \(description)"
            case let .duplicate(description): "duplicate: \(description)"
            case let .duplicateArchive(description): "duplicateArchive: \(description)"
            case let .badfilename(description): "badfilename: \(description)"
            }
        }

        internal init?(withRawMediaWikiKey key: String, description: String) {
            switch key {
                case "exists-normalized":
                self = .exists(description: description)
                case "exists":
                    self = .exists(description: description)
                case "was-deleted":
                    self = .wasDeleted(description: description)
                case "duplicate":
                    self = .exists(description: description)
                case "duplicate-archive":
                    self = .duplicateArchive(description: description)
                case "badfilename":
                    self = .badfilename(description: description)
                default:
                    assertionFailure("Missing MediaWiki upload warning key \(key). Add it to the initializier!")
                    return nil
            }
        }
    }
    
    enum Result: String, Decodable, Sendable {
        case success = "Success"
        case warning = "Warning"
    }
    
    public struct Upload: Decodable, Sendable {
        let result: String
        let sessionkey: String
        let filename: String?
        let filekey: String?
        public let warnings: [Warning]
        let badfilename: String?
        // let imageInfo: [...]
        
        enum CodingKeys: CodingKey {
            case result
            case sessionkey
            case filename
            case filekey
            case warnings
            case badfilename
        }
        
        public init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<FileUploadResponse.Upload.CodingKeys> = try decoder.container(keyedBy: FileUploadResponse.Upload.CodingKeys.self)
            self.result = try container.decode(String.self, forKey: FileUploadResponse.Upload.CodingKeys.result)
            self.sessionkey = try container.decode(String.self, forKey: FileUploadResponse.Upload.CodingKeys.sessionkey)
            self.filename = try container.decodeIfPresent(String.self, forKey: FileUploadResponse.Upload.CodingKeys.filename)
            self.filekey = try container.decodeIfPresent(String.self, forKey: FileUploadResponse.Upload.CodingKeys.filekey)
            
            let warningsDict = try container.decodeIfPresent([String: String].self, forKey: FileUploadResponse.Upload.CodingKeys.warnings)
            self.warnings = warningsDict?.compactMap(Warning.init) ?? []
            
            self.badfilename = try container.decodeIfPresent(String.self, forKey: FileUploadResponse.Upload.CodingKeys.badfilename)
        }
        
    }
}

public struct TokenAuthManagerInfo: Sendable, Equatable {
    public let token: String
    let type: TokenType
    public let captchaID: String?
    public let captchaURL: URL?
}

/// see: https://www.mediawiki.org/wiki/Help:Namespaces/en#ns-aliases
public enum MediawikiNamespace: Int, Decodable, Sendable {
    case media = -2
    case special = -1
    case main = 0
    case talk = 1
    case user = 2
    case userTalk = 3
    case project = 4
    case projectTalk = 5
    case file = 6
    case fileTalk = 7
    case mediawiki = 8
    case mediawikiTalk = 9
    case template = 10
    case templateTalk = 11
    case help =  12
    case helpTalk = 13
    case category = 14
    case categoryTalk = 15
}

enum WikimediaMetadataSource: String, Decodable, Sendable {
    case mediawikiMetadata = "mediawiki-metadata"
    case commonsDescriptionPage = "commons-desc-page"
    case commonsTemplates = "commons-templates"
    case commonsCategories = "commons-categories"
    case `extension` = "extension"
}

struct MetadataKeyValue: Decodable, Sendable {
    public let value: String
    public let source: WikimediaMetadataSource
}

public struct QueryListItem: Decodable, Hashable, Equatable, Sendable {
    public let ns: MediawikiNamespace
    public let pageid: Int64?
    public let title: String
}

public struct RawFileMetadata: Sendable, Identifiable {
    public let title: String
    public let pageid: Int64
    public var id: String { String(pageid) }
    public let pageData: FileMetadata
    public let structuredData: WikidataFileEntity
}


public struct GeosearchListItem: Decodable, Equatable, Hashable, Sendable, Identifiable {
    public let pageid: Int64
    public let ns: MediawikiNamespace
    public let title: String
    public let lat: Double
    public let lon: Double
    public let dist: Double
    public let primary: Bool
    
    public var id: String { String(pageid) }
}
public struct FileMetadata: Decodable, Sendable, Hashable, Equatable, Identifiable {
    public let pageid: Int64
    public let ns: MediawikiNamespace
    public let title: String
    public let imageinfo: ImageInfo
    public let categories: [QueryListItem]
    public let restrictiontypes: [RestrictionType]
    public let lastrevid: Int
    
    public var id: String { String(pageid) }
    
    /// "M" prefixed string from the pageid Int
    public var wikidataPageID: String { "M\(pageid)" }
    
    // see: https://www.mediawiki.org/wiki/Manual:$wgRestrictionTypes
    public enum RestrictionType: String, Decodable, Sendable  {
        case edit
        case move
        case upload
        case create
    }
    
    enum CodingKeys: CodingKey {
        case pageid
        case ns
        case title
        case imageinfo
        case coordinates
        case categories
        case lastrevid
        case restrictiontypes
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.pageid = try container.decode(Int64.self, forKey: .pageid)
        self.ns = try container.decode(MediawikiNamespace.self, forKey: .ns)
        self.title = try container.decode(String.self, forKey: .title)
        
        // NOTE: Most values are decoded as is from the API. imageinfo and coordinates are the only exception
        // as it is returned inside an array (with only one value).
        guard let imageinfo = try container.decode([FileMetadata.ImageInfo].self, forKey: .imageinfo).first else {
            throw CommonsAPIDecodingError.failedToDecodeImageInfoSingleValueArray
        }
        self.imageinfo = imageinfo
        
        self.categories = try container.decodeIfPresent([QueryListItem].self, forKey: .categories) ?? []
        self.lastrevid = try container.decode(Int.self, forKey: .lastrevid)
        self.restrictiontypes = try container.decode([RestrictionType].self, forKey: .restrictiontypes)
    }

    
    public struct ImageInfo: Decodable, Hashable, Equatable, Sendable {
        public let timestamp: Date
        public let user: String
        public let url: URL
        public let descriptionurl: URL
        
        // Optional image specific fields
        // because these could be nil for sound etc. (i suppose, needs to be tested).
        public let width: Double?
        public let height: Double?
        public let size: Double?
        public let thumburl: URL?
        public let thumbwidth: Double?
        public let thumbheight: Double?
        
        

        public let extmetadata: ExtMetadata?

        public struct ExtMetadata: Sendable, Hashable, Equatable, Decodable {
            public let imageDescription: [LanguageCode: String]
            public let attribution: String?
          
            
            private struct MetadataContainer<T: Decodable>: Decodable {
                let value: T
                let source: String
            }
            
            enum CodingKeys: CodingKey {
                case ImageDescription
                case Attribution
            }
            
            public init(from decoder: any Decoder) throws {
                do {
                    let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
                    
                    self.attribution = try? container.decode(MetadataContainer<String>.self, forKey: .Attribution).value
                    
                    /// key is the two-letter language code (eg. "en") eg: ["en": "a description", "de": "eine Beschreibung"]
                    let localizedDescriptions = try? container.decode(MetadataContainer<[String: String]>.self, forKey: .ImageDescription).value
                    if let localizedDescriptions {
                        self.imageDescription = localizedDescriptions
                    } else if let description = try? container.decode(MetadataContainer<String>.self, forKey: .ImageDescription).value {
                        Logger().warning("Found non-localized description, assuming \"en\" to be the correct one. May be wrong!")
                        self.imageDescription = ["en": description]
                    } else {
                        self.imageDescription = [:]
                    }
                    
                    
                    
                } catch(DecodingError.typeMismatch) {
                    // NOTE: if extmetadata is empty (eg. because filtering), its a JSON array, not a dictionary anymore
                    // so to handle this type mutation, we catch this case and simply init props with an empty state
                    self.imageDescription = [:]
                    self.attribution = nil
                } catch {
                    throw error
                }
            }
        }

    }
}

public struct WikidataEntityTranslation: Sendable {
    public let id: String
    let languageCode: LanguageCode
    public let label: String?
    public let entityDescription: String?
}


public struct WikidataSearchItem: Decodable, Sendable {
    public let id: String
    public let pageid: Int
    public let label: String
    public let description: String?
}

internal struct SearchWikidataEntityResponse: Decodable, Sendable {
    let search: [WikidataSearchItem]
    let searchContinue: Int?
}


internal struct SparqlValue<T: Decodable&Sendable>: Decodable, Sendable {
    let value: T
}

internal struct SPARQLResponse<BindingItem: Decodable&Sendable>: Decodable, Sendable {
    let head: Head
    let results: Results
    
    struct Head: Decodable, Sendable {
        let vars: [String]
    }
    
    struct Results: Decodable, Sendable {
        let bindings: [BindingItem]
    }
}

enum SparqlDecodingError: Error {
    case geoPointFailedDecoding(raw: String)
}

internal struct SparqlGeoPoint: Decodable, Sendable {
    let coordinate: CLLocationCoordinate2D
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        
        let sparqlGeoPointPattern = Regex {
            One("Point(")
            Capture(OneOrMore(.anyNonNewline), transform: CLLocationDegrees.init)
            One(.horizontalWhitespace)
            Capture(OneOrMore(.anyNonNewline), transform: CLLocationDegrees.init)
            One(")")
        }
        let match = text.firstMatch(of: sparqlGeoPointPattern)
        
        //NOTE: order in the sparql point is reversed compared to CLLocationCoordinate2D
        guard let longitude = match?.output.1,
              let latitude = match?.output.2 else {
            throw SparqlDecodingError.geoPointFailedDecoding(raw: text)
        }
        
        coordinate = .init(latitude: latitude, longitude: longitude)
    }
    
}

internal struct SparqlGenericWikidataItem: Decodable, Sendable {
    let commonsCategory: SparqlValue<String>?
    let id: SparqlValue<String>
    let area: SparqlValue<String>?
    let label: SparqlValue<String>?
    let description: SparqlValue<String>?
    /// comma separated list (eg. "Q1,Q42")
    let instances: SparqlValue<String>?
    let location: SparqlValue<SparqlGeoPoint>?
    let image: SparqlValue<URL>?
}

/// alias Q-Item
public struct GenericWikidataItem: Sendable, Hashable, Equatable, Identifiable, Decodable {
    public let commonsCategory: String?
    public let id: String

    
    public let label: String?
    public let description: String?
    /// the language used for label and description
    public let labelLanguage: String
        
    // the Q-Item instance
    public let instances: [String]?
    
    public let latitude: Double?
    public let longitude: Double?
    
    /// area in m^2
    public let area: Double?

    public var location: CLLocationCoordinate2D? {
        if let latitude, let longitude {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        } else {
            nil
        }
    }
    
    public let image: URL?
}


extension GenericWikidataItem {
    /// Q1: Universe
    public static func testItem() -> Self {
        Self(
            commonsCategory: "Universe",
            id: "Q1",
            label: "Universe",
            description:  "totality consisting of space, time, matter and energy",
            labelLanguage: "en",
            instances: ["Q36906466"],
            latitude: nil,
            longitude: nil,
            area: nil,
            image: URL(string: "http://commons.wikimedia.org/wiki/Special:FilePath/Cityscape%20Berlin.jpg")!
        )
    }
}

extension CLLocationCoordinate2D: @retroactive Equatable, @retroactive Hashable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
}

extension GenericWikidataItem {
    init(_ sparqlItem: SparqlGenericWikidataItem, language: String) {
        
        var area: Double?
        if let areaString = sparqlItem.area?.value {
            area = Double(areaString)
        }
        
        var instances: [String] = []
        if let instancesString = sparqlItem.instances?.value {
            instances = instancesString.components(separatedBy: ",")
        }
        
        self.init(
            commonsCategory: sparqlItem.commonsCategory?.value,
            id: sparqlItem.id.value,
            label: sparqlItem.label?.value,
            description: sparqlItem.description?.value,
            labelLanguage: language,
            instances: instances,
            latitude: sparqlItem.location?.value.coordinate.latitude,
            longitude: sparqlItem.location?.value.coordinate.longitude,
            area: area,
            image: sparqlItem.image?.value
        )
    }
}


struct LanguageValue: Codable {
    /// The language that was asked -for in the API request
    let forLanguage: String?
    /// the _actual_ language of the value. Differs from for-language when the language was not found and a fallback was choosen.
    let language: String
    let value: String
    
    enum CodingKeys: String, CodingKey {
        case language
        case forLanguage = "for-language"
        case value
    }
}
private func convertBulkyTranslations(_ bulkyTranslations: [String: LanguageValue]) -> [LanguageCode: String] {
    var keyValuePairs: [(LanguageCode, String)] = []
    var locales: Set<LanguageCode> = []
    for languageValue in bulkyTranslations.values {
        /// If it exists , we prefer to to use "for-language" as this is the language we asked for, even if we get a fallback.
        let locale = languageValue.forLanguage ?? languageValue.language
        guard !locales.contains(locale) else { continue }
        locales.insert(locale)
        keyValuePairs.append((locale, languageValue.value))
    }
    
    return .init(uniqueKeysWithValues: keyValuePairs)
}

public struct WikidataFileEntity: Sendable, Identifiable, Decodable {
    public let id: String
    public let pageid: UInt64?
    public let title: String?
    public let ns: MediawikiNamespace?
    public let modified: Date?
    public let missing: Bool
    
    public let labels: [String: String]
    
    /// aka "claims"
    public let statements: [WikidataProp: [WikidataClaim]]
    
    enum CodingKeys: CodingKey {
        case id
        case pageid
        case title
        case ns
        case modified
        case labels
        case statements
        case missing
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(String.self, forKey: .id)
        self.pageid = try container.decodeIfPresent(UInt64.self, forKey: .pageid)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.ns = try container.decodeIfPresent(MediawikiNamespace.self, forKey: .ns)
        self.modified = try container.decodeIfPresent(Date.self, forKey: .modified)
        
        if let bulkyLabels = try? container.decodeIfPresent([String : LanguageValue].self, forKey: .labels) {
            self.labels = convertBulkyTranslations(bulkyLabels)
        } else {
            self.labels = [:]
        }
        
        // NOTE: if empty, statements is an array instead of a dictionary, so soft-try here and fallback to empty dictionary
        let statements = try? container.decodeIfPresent([WikidataProp : [WikidataClaim]]?.self, forKey: .statements) ?? [:]
        self.statements = statements ?? [:]
        
        if let missingString = try container.decodeIfPresent(String.self, forKey: .missing),
           missingString == "true" {
            self.missing = true
        } else {
            self.missing = false
        }
    }
}

public typealias LanguageCode = String
public struct WikidataEntity: Sendable, Decodable, Identifiable {
    public let id: String
    public let type: String?
    public let labels: [LanguageCode: String]
    public let descriptions: [LanguageCode: String]
    
    enum CodingKeys: CodingKey {
        case type
        case id
        case labels
        case descriptions
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.id = try container.decode(String.self, forKey: .id)
        if let bulkyLabels = try container.decodeIfPresent([String: LanguageValue].self, forKey: .labels) {
            self.labels = convertBulkyTranslations(bulkyLabels)
        } else {
            self.labels = [:]
        }
        
        if let bulkyDescriptions = try container.decodeIfPresent([String: LanguageValue].self, forKey: .descriptions) {
            self.descriptions = convertBulkyTranslations(bulkyDescriptions)
        } else {
            self.descriptions = [:]
        }
    }
    
}

extension UserContributionListItem: Identifiable {
    public var id: String { "\(pageid)-\(revid)" }
}



// MARK: Upload

public struct MediaFileUploadable: Identifiable, Hashable, Equatable, Sendable, Codable {
    public let id: String
    
    /// The file url from which to upload the Data
    public let fileURL: URL
    
    /// How the file should be named on the other side (including the file extension which _must_ be present) : eg. "file 123.jpg" but not "file 123"
    public let filename: String
    
    public let wikiText: String
    public let captions: [LanguageString]
    public let claims: [WikidataClaim]
    
    public enum Author {
        /// "self" means that the username is also uploader
        case username(username: String, displayString: String?, self: Bool)
        case string(String)
//        case wikidataItem(WikidataItemID)
    }
    
    public init(
        id: String,
        fileURL: URL,
        filename: String,
        claims: [WikidataClaim],
        captions: [LanguageString],
        wikitext: String
    ) {
        if filename.fileExtension().isEmpty {
            Logger().warning("Filename must include a file extension (eg.: .jpg) otherwise the upload will likely fail with a MediaWiki warning.")
            assertionFailure()
        }
        
        self.id = id
        self.filename = filename
        self.fileURL = fileURL
        self.captions = captions
        self.claims = claims
        self.wikiText = wikitext
    }
}


/*
 
 
 {
 "upload": {
 "result": "Warning",
 "warnings": {
 "badfilename": "My_bad:filename.png"
 },
 "filekey": "19mmz8arzreg.9md1cj.2283740.png",
 "sessionkey": "19mmz8arzreg.9md1cj.2283740.png"
 }
 }
 
 
 */

// MARK: - Internal Types
// These are types that are mainly used to decode the mediawiki/commons-API responses,
// and should not bleed into the app that imports the package.


// MARK: Query

/// A generic query response when `action: query`
internal struct QueryResponse<T: Decodable&Sendable>: Decodable, Sendable {
//    var batchcomplete: Bool|String
    let curtimestamp: Date
    let query: T?
    let `continue`: Continue?
    
    struct Continue: Decodable, Sendable {
        // see: https://www.mediawiki.org/wiki/API:Continue
        
        let `continue`: String
        
        // Various forms of continue sub-parts:
        
        /// for query=search
        let sroffset: Int?
        
        /// for list=categorymembers
        let cmcontinue: String?
        
        /// for list=allimages
        let aicontinue: String?

        /// for generator=search
//        let gsroffset: Int?
    }
}

public struct ImageListResponse: Sendable {
    public let continueString: String?
    public let files: [QueryListItem]
}


// query: prop=url|timestamp|user|commonmetadata|badfile|metadata|extmetadata ...
internal struct AllImagesListResponse: Decodable, Sendable {
    let allimages: [QueryListItem]
}

internal struct FileMetadataListResponse: Decodable, Sendable {
    let pages: [FileMetadata]
}

public struct GeosearchListResponse: Decodable, Sendable {
    let geosearch: [GeosearchListItem]
}

// query: list=search
internal struct SearchListResponse: Decodable, Sendable {
    let search: [QueryListItem]
}

// query: list=categorymembers
internal struct CategoryMembersListResponse: Decodable, Sendable {
    let categorymembers: [QueryListItem]
}

// query: list=categorymembers
internal struct CategoryResponse: Decodable, Sendable {
    let categorymembers: [QueryListItem]
    let pages: [ParentCategoryPage]?
    
    struct ParentCategoryPage: Decodable {
        let title: String
        let pageprops: PageProps?
        let categories: [QueryListItem]
        
        struct PageProps: Decodable {
            /// Image name associated with the category/page
            let page_image_free: String?
                
            /// Q-Item with the "Q" prefix
            private let wikibase_item: String? // or just string
            
            var wikidataItem: WikidataItemID? {
                if let wikibase_item {
                    WikidataItemID(stringValue: wikibase_item)
                } else {
                    nil
                }
            }
        }
    }
}

// query: list=usercontribs
internal struct UserContributionListResponse: Decodable, Sendable {
    let usercontribs: [UserContributionListItem]
}

// query: action=wbgetentities?titles=File:test.jpg|...
internal struct FileEntitiesResponse: Decodable, Sendable {
    let entities: [String: WikidataFileEntity]
}

// query: action=wbgetentities?ids=P180|Q5432|...
internal struct EntitiesResponse: Decodable, Sendable {
    typealias WikidataID = String
    let entities: [WikidataID: WikidataEntity]
}

internal struct UserContributionListItem: Decodable, Sendable {
    public let user: String
    public let pageid: Int
    public let revid: Int
    public let parentid: Int
    public let ns: MediawikiNamespace
    public let title: String
    public let timestamp: Date
    /// whether it is a new contribuation (aka initial upload)
    public let new: Bool
    /// wether this is a minor edit
    public let minor: Bool
    public let top: Bool
    /// contains a comment what this contribution is, eg.: "Uploaded own work with UploadWizard".
    public let comment: String
    public let size: Int
}

internal struct AuthManagerOrTokensResponse: Decodable {
    /// tokens that where requested
    let tokens: Tokens?
    let authmanagerinfo: AuthManagerInfo?
    
    struct Tokens: Decodable {
        /// the CSFR (Cross-Site Request Forgery) token that must be used to all future requests.
        var csrftoken: String?
        var logintoken: String?
        var createaccounttoken: String?
    }
    
    struct AuthManagerInfo: Decodable {
        struct Request: Decodable {
            let id: String
            let fields: [String: Field]?
            
            struct Field: Decodable {
                let type: String?
                let value: String?
                let label: String?
                let help: String?
            }
        }
        
        
        let requests: [Request]
    }
}


internal struct AuthManagerInfoResponse: Decodable {
    /// tokens that where requested
    let authmanagerinfo: AuthManagerInfo
    
    struct AuthManagerInfo: Decodable {
        var canauthenticatenow: String?
        var cancreateaccounts: String?
        var canlinkaccounts: String?
        var haspreservedstate: String?
        var hasprimarypreservedstate: String?
        var preservedusername: String?
    }
}

// MARK: Login

public struct LoginResponseWrapped: Sendable, Decodable {
    let clientlogin: LoginResponse
}

// Could this be the same struct as CreateAccountResponse
public struct LoginResponse: Sendable, Decodable {
    public let status: AuthStatus
    public let message: String?
    public let messagecode: String?
}

extension AuthStatus: CustomStringConvertible {
    public var description: String { rawValue }
}

extension LoginResponseWrapped: CustomDebugStringConvertible {
    public var debugDescription: String {
        "status: \(clientlogin.status), message: \(clientlogin.message ?? "-"), messageCode: \(clientlogin.messagecode ?? ""))"
    }
}

// MARK: Create Account (Register / Signup)


public struct CreateAccountResponseWrapped: Decodable, Sendable {
    let createaccount: CreateAccountResponse
}

public struct CreateAccountResponse: Decodable, Sendable {
    public let status: AuthStatus
    public let message: String?
    public let messagecode: MessageCode?
    
    /// see: https://www.mediawiki.org/wiki/API:Account_creation#Possible_errors
    public enum MessageCode: String, Error, Decodable, Sendable {
        /// Invalid create account token
        case badtoken
        
        /// The token parameter must be set.
        case notoken
        
        /// The following parameter was found in the query string, but must be in the POST body: createtoken.
        case mustpostparams
        
        /// At least one of the parameters "createcontinue" and "createreturnurl" is required.
        case missingparam
        
        /// The supplied credentials could not be used for account creation.
        case authmanagerCreateNoPrimary = "authmanager-create-no-primary"
        
        /// You need to provide a valid email address.
        case noemailcreate
        
        /// The email address cannot be accepted as it appears to have an invalid format.
        /// Please enter a well-formatted address or empty that field.
        case invalidemailaddress
        
        /// The passwords you entered do not match.
        case badretype
        
        /// Username entered already in use.
        /// Please choose a different name.
        case userexists
        
        /// Incorrect or missing CAPTCHA.
        case captchaCreateAccountFail = "captcha-createaccount-fail"
        
        /// Visitors to this wiki using your IP address have created num accounts in the last day, which is the maximum allowed in this time period.
        ///  As a result, visitors using this IP address cannot create any more accounts at the moment.
        ///  If you are at an event where contributing to Wikimedia projects is the focus, please see Requesting temporary lift of IP cap to help resolve this issue.
        case accountCreationThrottleHit = "acct_creation_throttle_hit"
    }
}

public enum UsernamePasswordValidation: Sendable {
    case good
    case passwordTooShort
    case passwordTooLong
    case passwordInCommonList
    case passwordMissing
    case passwordContainsUsername
    case passwordInvalid
    case unknownInvalidation
    case badUser
    case userExists
}

public enum CreateAccountParamValidationError: Error, Sendable {
    case unknownResponse(String)
}

public struct ValidityMessage: Sendable, Decodable {
    let message: String
    let type: MessageType?
    let code: Code?
    
    // see: https://doc.wikimedia.org/mediawiki-core/REL1_39/php/PasswordPolicyChecks_8php_source.html
    
    enum Code: String, Sendable, Decodable {
        case passwordTooShort = "passwordtooshort"
        case passwordTooLong = "passwordtoolong"
        case passwordInCommonList = "passwordincommonlist"
        /// eg. for "ExamplePassword"
        case passwordLoginForbidden = "password-login-forbidden"
        case passwordSubstringUsernameMatch = "password-substring-username-match"
    }
    
    enum MessageType: String, Sendable, Decodable {
        case error
        case warning
    }
}

internal struct ValidatePasswordResponse: Sendable, Decodable {
    let validatepassword: Validity?
    let error: ValidateError?
    
    struct ValidateError: Sendable, Decodable {
        let code: Code
        let info: String
        let docref: String
        
        enum Code: String, Sendable, Decodable {
            /// Username entered already in use.
            case userExists = "userexists"
            /// The password parameter must be set.
            case noPassword = "nopassword"
            /// Invalid value "username" for user parameter user. (eg. should not be an email address)
            case badUser = "baduser_user"
        }
    }
    
    struct Validity: Sendable, Decodable {
        let validity: PasswordValidationStatus
        let validitymessages: [ValidityMessage]?
        
        enum PasswordValidationStatus: String, Sendable, Decodable {
            /// password is acceptable
            case good = "Good"
            /// Password may be used for login but must be changed
            case change = "Change"
            case invalid = "Invalid"
        }
    }
}


extension UsernamePasswordValidation {
    init(withRawResponse rawResponse: ValidatePasswordResponse) {
        if let validationError = rawResponse.error {
            self = switch validationError.code {
            case .badUser: .badUser
            case .noPassword: .passwordMissing
            case .userExists: .userExists
            }
        } else if let validationStatus = rawResponse.validatepassword {
            self = switch validationStatus.validity {
            case .good: .good
            case .change:
                if let message = validationStatus.validitymessages?.first {
                    switch message.code {
                    case .passwordInCommonList: .passwordInCommonList
                    case .passwordLoginForbidden: .passwordInvalid
                    case .passwordSubstringUsernameMatch: .passwordContainsUsername
                    case .passwordTooLong: .passwordTooLong
                    case .passwordTooShort: .passwordTooShort
                    case .none: .passwordInvalid
                    }
                } else {
                    .passwordInvalid
                }
            case .invalid: .passwordInvalid
            }
        } else {
            assertionFailure("We should be able to parse this with some message")
            self = .unknownInvalidation
        }
    }
}

