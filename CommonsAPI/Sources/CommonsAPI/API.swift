//
//  API.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 24.09.24.
//

import CoreLocation
import Foundation
import os.log
import Algorithms
#if DEBUG
@preconcurrency import Pulse
#endif

internal typealias Parameters = [String:String]

public actor API {
    let logger = Logger(subsystem: "CommonsFinder", category: "CommonsAPI")
    let wikipediaHomepage = URL(string: "https://wikipedia.org")!
    
    let commonsHomepage = URL(string: "https://commons.wikimedia.org")!
    let commonsEndpoint = URL(string: "https://commons.wikimedia.org/w/api.php")!
    let wikidataEndpoint = URL(string: "http://www.wikidata.org/w/api.php")!
    
    // see: https://www.wikidata.org/wiki/Wikidata:SPARQL_query_service
    let wikidataSparqlEndpoint = URL(string: "https://query.wikidata.org/bigdata/namespace/wdq/sparql")!
    let createAccountRedirectURL = URL(string: "https://commons.m.wikimedia.beta.wmflabs.org/w/index.php?title=Main_Page&welcome=yes")!
    
    let userAgent: String
    
#if DEBUG
    let urlSession = URLSessionProxy(configuration: URLSessionConfiguration.default)
#else
    let urlSession = URLSession(configuration: URLSessionConfiguration.default)
#endif
    
    private lazy var jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()


    public init(userAgent: String) {
        self.userAgent = userAgent

 // Un-Comment the following code block to test EmailAuth via email-code (https://www.mediawiki.org/wiki/Help:Extension:EmailAuth)
//#if DEBUG
//        let c1 = HTTPCookie(properties: [
//            .domain: "auth.wikimedia.org",
//            .name: "forceEmailAuth",
//            .path: "/",
//            .value: "1",
//            .expires: Date().addingTimeInterval(600)
//        ])
//        
//        let c2 = HTTPCookie(properties: [
//            .domain: "commons.wikimedia.org",
//            .name: "forceEmailAuth",
//            .path: "/",
//            .value: "1",
//            .expires: Date().addingTimeInterval(600)
//        ])
//        
//        if let c1, let c2 {
//            configuration.httpCookieStorage?.setCookie(c1)
//            configuration.httpCookieStorage?.setCookie(c2)
//
//        } else {
//            assertionFailure()
//        }
// #endif
        
//        var eventMonitors: [any EventMonitor] = [AlamofireNotifications()]
        
}
    
    private func parse<T: Decodable>(_ type: T.Type, from data: Data, response: URLResponse) throws -> T {
        guard let http = response as? HTTPURLResponse else {
            throw CommonAPIError.invalidResponseType(rawDataString: String(data: data, encoding: .utf8))
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CommonAPIError.httpError(statusCode: http.statusCode)
        }
        return try jsonDecoder.decode(T.self, from: data)
    }

    // MARK: - Tokens

    private func fetchToken(type: TokenType, includeAuthmanagerInfo: Bool = false) async throws -> TokenAuthManagerInfo {
        var query: Parameters = [
            "format": "json",
            "curtimestamp": "1",
            "action": "query",
            "type": type.description
        ]

        if includeAuthmanagerInfo {
            query["meta"] = "tokens|authmanagerinfo"
            switch type {
            case .login:
                query["amirequestsfor"] = "login"
            case .createAccount:
                query["amirequestsfor"] = "create"
            case .csrf:
                assertionFailure("Requesting auth manager info when fetching CSRF token is unexpected.")
            }
        } else {
            query["meta"] = "tokens"
        }

        let request = try URLRequest.GET(url: commonsEndpoint, query: query)
        let (data, response) = try await urlSession.data(for: request)

        let value = try parse(QueryResponse<AuthManagerOrTokensResponse>.self, from: data, response: response)

        guard let tokens = value.query?.tokens else {
            throw CommonAPIError.requestedTokenTypeMissing(type)
        }

        let fetchedToken: String? = {
            switch type {
            case .login: return tokens.logintoken
            case .createAccount: return tokens.createaccounttoken
            case .csrf: return tokens.csrftoken
            }
        }()

        guard let fetchedToken else {
            throw CommonAPIError.requestedTokenTypeMissing(type)
        }
        if fetchedToken.count <= 3 {
            throw CommonAPIError.tokenTooShort(type)
        }

        let captchaRequest = value.query?.authmanagerinfo?.requests.first(where: { $0.id == "CaptchaAuthenticationRequest" })
        let captchaID = captchaRequest?.fields?["captchaId"]?.value
        var captchaURL: URL?
        if let captchaPath = captchaRequest?.fields?["captchaInfo"]?.value {
            captchaURL = URL(string: commonsHomepage.absoluteString.appending(captchaPath))
        }

        return TokenAuthManagerInfo(token: fetchedToken, type: type, captchaID: captchaID, captchaURL: captchaURL)
    }

    
    public func fetchCreateAccountInfo() async throws -> TokenAuthManagerInfo {
        try await fetchToken(
            type: .createAccount,
            includeAuthmanagerInfo: true
        )
    }
    
    public func fetchCSRFToken() async throws -> String {
        try await fetchToken(type: .csrf).token
    }

    // MARK: Login

    internal func login(
        usingLoginToken loginToken: String,
        username: String,
        password: String
    ) async throws -> LoginResponse {
        let form: Parameters = [
            "action": "clientlogin",
            "curtimestamp": "1",
            "format": "json",
            "loginreturnurl": wikipediaHomepage.absoluteString,
            "logintoken": loginToken,
            "username": username,
            "password": password,
            "rememberMe": "1"
        ]
        var request = try URLRequest.POST(url: commonsEndpoint, form: form)
        // Optional: Referer can help in some CSRF contexts; generally not required for clientlogin.
        request.setValue("https://commons.wikimedia.org/wiki/Special:UserLogin", forHTTPHeaderField: "Referer")

        let (data, response) = try await urlSession.data(for: request)
        let wrapped = try parse(LoginResponseWrapped.self, from: data, response: response)
        return wrapped.clientlogin
    }
    
    public func createAccount(
        usingCreateAccountToken loginToken: String,
        captchaWord: String,
        captchaID: String,
        username: String,
        password: String,
        email: String
    ) async throws -> CreateAccountResponse {
        let form: Parameters = [
            "action": "createaccount",
            "curtimestamp": "1",
            "format": "json",
            "createreturnurl": createAccountRedirectURL.absoluteString,
            "createtoken": loginToken,
            "username": username,
            "password": password,
            "retype": password,
            "captchaWord": captchaWord,
            "captchaId": captchaID,
            "email": email
        ]
        var request = try URLRequest.POST(url: commonsEndpoint, form: form)
        request.setValue("https://commons.wikimedia.org/wiki/Special:CreateAccount", forHTTPHeaderField: "Referer")

        let (data, response) = try await urlSession.data(for: request)
        let wrapped = try parse(CreateAccountResponseWrapped.self, from: data, response: response)
        return wrapped.createaccount
    }
    
    /// Login to Wikimedia user-account (sign-in)
    public func login(username: String, password: String) async throws -> LoginResponse {
        let loginToken = try await fetchToken(type: .login).token
        let status = try await login(
            usingLoginToken: loginToken,
            username: username,
            password: password
        )
        return status
    }
    
    public func continueLogin(emailCode: String) async throws -> LoginResponse {
        let loginToken = try await fetchToken(type: .login).token
        
        let form: Parameters = [
            "action": "clientlogin",
            "curtimestamp": "1",
            "format": "json",
            "loginreturnurl": wikipediaHomepage.absoluteString,
            "logintoken": loginToken,
            "rememberMe": "1",
            "token": emailCode,
            "logincontinue": "1"
        ]
        var request = try URLRequest.POST(url: commonsEndpoint, form: form)
        request.setValue("https://commons.wikimedia.org/wiki/Special:UserLogin", forHTTPHeaderField: "Referer")

        let (data, response) = try await urlSession.data(for: request)
        let wrapped = try parse(LoginResponseWrapped.self, from: data, response: response)
        return wrapped.clientlogin
    }
    
    public func continueLogin(twoFactorCode: String) async throws -> LoginResponse {
        let loginToken = try await fetchToken(type: .login).token
        
        let form: Parameters = [
            "action": "clientlogin",
            "curtimestamp": "1",
            "format": "json",
            "loginreturnurl": wikipediaHomepage.absoluteString,
            "logintoken": loginToken,
            "rememberMe": "1",
            "OATHToken": twoFactorCode,
            "logincontinue": "1"
        ]
        var request = try URLRequest.POST(url: commonsEndpoint, form: form)
        request.setValue("https://commons.wikimedia.org/wiki/Special:UserLogin", forHTTPHeaderField: "Referer")

        let (data, response) = try await urlSession.data(for: request)
        let wrapped = try parse(LoginResponseWrapped.self, from: data, response: response)
        return wrapped.clientlogin
    }

    public func validateUsernamePassword(username: String, password: String, email: String) async throws -> UsernamePasswordValidation {
        let form: Parameters = [
            "action": "validatepassword",
            "user": username,
            "password": password,
            "email": email,
            "curtimestamp": "1",
            "format": "json",
            "formatversion": "2"
        ]
        
        let request = try URLRequest.POST(url: commonsEndpoint, form: form)
        let (data, response) = try await urlSession.data(for: request)
        
        let responseValue = try parse(ValidatePasswordResponse.self, from: data, response: response)
        return UsernamePasswordValidation(withRawResponse: responseValue)
    }
    
    // see: https://commons.wikimedia.org/w/api.php?action=help&modules=query%2Busercontribs
    
    /// limit: 1..50 (default: 50, for clients with higher limits, the max limit is: 500)
    private func listUserContribs(of username: String, limit: ListLimit) async throws -> [UserContributionListItem] {
        let query: Parameters = [
            "action": "query",
            "curtimestamp": "1",
            "list": "usercontribs",
            "ucuser": username,
            // new -> new contributions aka uploads
            "ucshow": "new",
            // 6 == File (https://www.mediawiki.org/wiki/Help:Namespaces/en#ns-aliases)
            "ucnamespace": String(MediawikiNamespace.file.rawValue),
            "uclimit": limit.apiString,
            "format": "json",
            "formatversion": "2"
        ]
        
        let request = try URLRequest.GET(url: commonsEndpoint, query: query)
        let (data, response) = try await urlSession.data(for: request)
        let responseValue = try parse(QueryResponse<UserContributionListResponse>.self, from: data, response: response)
        return responseValue.query?.usercontribs ?? []
    }
    
    
    /// listUserImages
    /// - Parameters:
    ///   - username: list items for this user
    public func listUserImages(
        of username: String,
        limit: ListLimit = .max,
        start: Date?,
        end: Date?,
        direction: ListDirection,
        continueString: String?
    ) async throws -> UserImagesListResponse {
        var query: Parameters = [
            "action": "query",
            "curtimestamp": "1",
            "list": "allimages",
            "aiuser": username,
            "aidir": direction.rawValue,
            "ailimit": limit.apiString,
            "aiprop": "",
            "aisort": "timestamp",
            "format": "json",
            "formatversion": "2"
        ]
        if let start {
            query["aistart"] = start.ISO8601Format()
        }
        if let end {
            query["aiend"] = end.ISO8601Format()
        }
        if let continueString, !continueString.isEmpty {
            query["aicontinue"] = continueString
        }
        
        let request = try URLRequest.GET(url: commonsEndpoint, query: query)
        let (data, response) = try await urlSession.data(for: request)
        let responseValue = try parse(QueryResponse<AllImagesListResponse>.self, from: data, response: response)

        // NOTE: "allimages" list doesnt return pageid for some reason (only with generator, which
        // we like to avoid due to sort order and pagination complications.
        let titles = responseValue.query?.allimages.map(\.title) ?? []
        
        return .init(continueString: responseValue.continue?.aicontinue, titles: titles)
    }
    
    
    public struct CommonsCategoryInfo: Sendable {
        public let title: String
        public let subCategories: [String]
        public let parentCategories: [String]
        /// NOTE: This is not the main Wikidata item, but the one for the category!
        /// eg. for "physics": https://www.wikidata.org/wiki/Q1457258
        /// instead of:  https://www.wikidata.org/wiki/Q413
        public let wikidataItem: WikidataItemID?
    }
    
    /// returns parent and sub-categories and wikidata item if available
    public func fetchCategoryInfo(of category: String) async throws -> CommonsCategoryInfo? {
        let query: Parameters = [
            "action": "query",
            "formatversion": "2",
            "list": "categorymembers",
            "prop": "categories|pageprops",
            "cmtitle": "Category:\(category)",
            "titles": "Category:\(category)",
            "cmprop": "title",
            "cmtype": "subcat",
            "cmnamespace": String(MediawikiNamespace.category.rawValue),
            "cmlimit": "500",
            "cllimit": "500",
            "clshow": "!hidden",
            "format": "json",
            "curtimestamp": "1"
        ]
        
        let request = try URLRequest.GET(url: commonsEndpoint, query: query)
        let (data, response) = try await urlSession.data(for: request)
        let result = try parse(QueryResponse<CategoryResponse>.self, from: data, response: response)
        
        guard let result = result.query else {
            return nil
        }
        
        let rawSubCategories = result.categorymembers
        let rawParentCategories = result.pages?.first?.categories ?? []
        let wikidataItem = result.pages?.first?.pageprops?.wikidataItem
        
        assert(rawSubCategories.allSatisfy { $0.ns == .category }, "We expect all items to be (sub)-categories")
        
        let subCategories: [String] = rawSubCategories.compactMap {
            String($0.title.split(separator: "Category:")[0])
        }
        let parentCategories: [String] = rawParentCategories.compactMap {
            String($0.title.split(separator: "Category:")[0])
        }
        
        assert(rawSubCategories.count == subCategories.count, "We expect all categories to have the \"Category:\" prefix")
        
        return CommonsCategoryInfo(
            title: category,
            subCategories: subCategories,
            parentCategories: parentCategories,
            wikidataItem: wikidataItem
        )
    }
    
    public func listCategoryImagesRaw(of category: String, continueString: String? = nil, limit: ListLimit = .max) async throws -> CategoryImageListResponse {
        var query: Parameters = [
            "action": "query",
            "list": "categorymembers",
            "redirects": "1",
            "prop": "info",
            "clshow": "!hidden",
            "cllimit": "max",
            "cmtitle": "Category:\(category)",
            "cmprop": "ids|title",
            "cmtype": "file",
            "cmnamespace": String(MediawikiNamespace.file.rawValue),
            "cmlimit": limit.apiString,
            "format": "json",
            "formatversion": "2",
            "curtimestamp": "1"
        ]
        
        if let continueString {
            query["cmcontinue"] = continueString
        }
        
        let request = try URLRequest.GET(url: commonsEndpoint, query: query)
        let (data, response) = try await urlSession.data(for: request)
        let value = try parse(QueryResponse<CategoryMembersListResponse>.self, from: data, response: response)
        
        return .init(
            continueString: value.continue?.cmcontinue,
            files: value.query?.categorymembers ?? []
        )
    }
    
    /// Augment existing partial file info with structured data
    public func fetchFileMetadata(fileMetadataList: [FileMetadata]) async throws -> [RawFileMetadata] {
        let structuredData = try await fetchStructuredData(.pageids(fileMetadataList.map(\.id)))
        var result: [RawFileMetadata] = []
        
        for fileMetadata in fileMetadataList {
            guard let wikiItem = structuredData[fileMetadata.wikidataPageID] else {
                logger.warning("We expect to find a wikidata entry for each page, \(fileMetadata.id) doesnt have one. Failed upload?")
                continue
            }
            result.append(.init(title: fileMetadata.title, pageid: fileMetadata.pageid, pageData: fileMetadata, structuredData: wikiItem))
        }
        return result
    }
    
    /// fetch file info and  structured data to form a RawFileMetadata
    public func fetchFullFileMetadata(_ identifiers: FileIdentifierList) async throws -> [RawFileMetadata] {
        
        async let pageQueryTask = fetchImageMetadata(identifiers)
        async let structuredDataTask = fetchStructuredData(identifiers)
        
        let (fileMetadataList, structuredDataItems) = try await (pageQueryTask, structuredDataTask)
        
        // dict on either pageid or title as key
        var result: [String: RawFileMetadata] = [:]
        
        for fileMetadata in fileMetadataList {
            guard let structuredData = structuredDataItems[fileMetadata.wikidataPageID] else {
                logger.warning("We expect to find a wikidata entry for each page, \(fileMetadata.id) doesnt have one. Failed upload?")
                continue
            }
            let item = RawFileMetadata(
                title: fileMetadata.title,
                pageid: fileMetadata.pageid,
                pageData: fileMetadata,
                structuredData: structuredData
            )
            
            switch identifiers {
            case .titles(_):
                result[item.title] = item
            case .pageids(_):
                result[item.id] = item
            }
        }

        // Mapping the result based on the original order, since the fetch order is not guaranteed
        return identifiers.items.compactMap { result[$0] }
    }
    
    // Example: https://commons.wikimedia.org/w/api.php?action=query&format=json&prop=imageinfo&titles=File%3The_Earth_seen_from_Apollo_17.jpg&formatversion=2&iiprop=url%7Cextmetadata&iiurlwidth=640&iiurlheight=640&iiextmetadatamultilang=1
    internal func fetchImageMetadata(_ identifiers: FileIdentifierList) async throws -> [FileMetadata] {
        var query: Parameters = [
            "action": "query",
            "curtimestamp": "1",
            "prop": "imageinfo|categories|info",
            "exportschema": "0.11",
            "formatversion": "2",
            "clshow": "!hidden",
            "cllimit": "max",
            "iilimit": "1",
            "inprop": "protection",
            "iiprop": "url|timestamp|user|dimensions|extmetadata|size",
            "iiextmetadatafilter": "ImageDescription|Attribution",
            "iiurlwidth": "640",
            "iiurlheight": "640",
            "smaxage": "60",
            "maxage": "60",
            "format": "json"
        ]
        
        switch identifiers {
        case .titles(var titles):
            if titles.count >= 50 {
                logger.warning("Trying to fetch metadata for \(titles.count) titles. However only 50 are supported at one time. Will be limited to 10.")
                titles = Array(titles.prefix(50))
            }
            query["titles"] = titles.joined(separator: "|")
        case .pageids(var pageIDs):
            if pageIDs.count >= 50 {
                logger.warning("Trying to fetch metadata for \(pageIDs.count) titles. However only 50 are supported at one time. Will be limited to 10.")
                pageIDs = Array(pageIDs.prefix(50))
            }
            query["pageids"] = pageIDs.joined(separator: "|")
        }
        
        let request = try URLRequest.GET(url: commonsEndpoint, query: query)
        let (data, response) = try await urlSession.data(for: request)
        let value = try parse(QueryResponse<FileMetadataListResponse>.self, from: data, response: response)
        let pages = value.query?.pages ?? []
        return pages
    }
    
    
    public struct FileSearchQueryResponse: Sendable {
        public let items: [FileMetadata]
        public let offset: Int?
    }
    
    public struct GenericSearchQueryResponse: Sendable {
        public let items: [QueryListItem]
        public let suggestion: String?
        public let offset: Int?
    }
    
    public enum SearchSort: String, Sendable {
        case relevance
        case createTimestampDesc = "create_timestamp_desc"
        case createTimestampAsc = "create_timestamp_asc"
        case incomingLinksDesc = "incoming_links_desc"
        case incomingLinksAsc = "incoming_links_asc"
        case lastEditDesc = "last_edit_desc"
        case lastEditAsc = "last_edit_asc"
        case just_match = "just_match"
        case random
    }
    
    private func search(
        for term: String,
        namespace: MediawikiNamespace,
        sort: SearchSort = .relevance,
        limit: ListLimit = .max,
        additionalParams: Parameters? = nil,
        offset: Int? = nil
    ) async throws -> GenericSearchQueryResponse {

        var query: Parameters = [
            "action": "query",
            "list": "search",
            "redirects": "1",
            "srsearch":  term,
            "srsort": sort.rawValue,
            "srnamespace": String(namespace.rawValue),
            "srlimit": limit.apiString,
            "srprop": "timestamp",
            "maxage": "60",
            "exportschema": "0.11",
            "formatversion": "2",
            "curtimestamp": "1",
            "format": "json"
        ]
        
        if let additionalParams {
            for (key,value) in additionalParams {
                query[key] = value
            }
        }
        if let offset {
            query["sroffset"] = String(offset)
        }
        
        let request = try URLRequest.GET(url: commonsEndpoint, query: query)
        let (data, response) = try await urlSession.data(for: request)
        let resultValue = try parse(QueryResponse<SearchListResponse>.self, from: data, response: response)
        guard let resultQuery = resultValue.query else {
            return .init(items: [], suggestion: nil, offset: nil)
        }
        return .init(
            items: resultQuery.search,
            suggestion: resultQuery.searchinfo.suggestion,
            offset: resultValue.continue?.sroffset
        )
    }
    
    public func searchFiles(for term: String, sort: SearchSort = .relevance, limit: ListLimit = .max, offset: Int? = nil) async throws -> GenericSearchQueryResponse {
        let additionalParams: Parameters = [
            "prop": "info",
            "clshow": "!hidden",
            "cllimit": "max",
        ]
        return try await search(for: term, namespace: .file, sort: sort, limit: limit, additionalParams: additionalParams, offset: offset)
    }
    
    public func searchCategories(for term: String, sort: SearchSort = .relevance, limit: ListLimit = .max, offset: Int? = nil) async throws -> GenericSearchQueryResponse {
        try await search(for: term, namespace: .category, sort: sort, limit: limit, additionalParams: [:], offset: offset)
    }
    
    // https://commons.wikimedia.org/w/api.php?action=query&format=json&prop=&continue=gsroffset%7C%7C&generator=geosearch&redirects=1&formatversion=2&ggscoord=37.786971%7C-122.399677&ggsradius=5000&ggssort=relevance&ggsglobe=earth&ggsnamespace=6&ggsprop=
    public func geoSearchFiles(topLeft: CLLocationCoordinate2D, bottomRight: CLLocationCoordinate2D) async throws -> [GeoSearchFileItem] {
        
        enum Sort: String {
            case distance
            case relevance
        }
        let boundingBoxString = "\(topLeft.latitude)|\(topLeft.longitude)|\(bottomRight.latitude)|\(bottomRight.longitude)"
        
        let query: Parameters = [
            "action": "query",
            "list": "geosearch",
            "gsbbox": boundingBoxString,
            "gssort": Sort.relevance.rawValue,
            "gsnamespace": String(MediawikiNamespace.file.rawValue),
            "gslimit": "max",
            "maxage": "60",
            "exportschema": "0.11",
            "formatversion": "2",
            "curtimestamp": "1",
            "format": "json"
        ]
        
        let request = try URLRequest.GET(url: commonsEndpoint, query: query)
        let (data, response) = try await urlSession.data(for: request)
        let resultValue = try parse(QueryResponse<GeosearchListResponse>.self, from: data, response: response)
        guard let resultQuery = resultValue.query else {
            return []
        }
        return resultQuery.geosearch

    }
    
    public func geoSearchFiles(around coordinate: CLLocationCoordinate2D, radius: CLLocationDistance) async throws -> [GeoSearchFileItem] {
        
        enum Sort: String {
            case distance
            case relevance
        }
        
        let radius = Int(radius.rounded(.awayFromZero))
        let gscoord = "\(coordinate.latitude)|\(coordinate.longitude)"
        
        let query: Parameters = [
            "action": "query",
            "list": "geosearch",
            "gscoord": gscoord,
            "gsradius": String(radius),
            "gssort": Sort.distance.rawValue,
            "gsnamespace": String(MediawikiNamespace.file.rawValue),
            "gslimit": "max",
            "maxage": "60",
            "exportschema": "0.11",
            "formatversion": "2",
            "curtimestamp": "1",
            "format": "json"
        ]
        
        let request = try URLRequest.GET(url: commonsEndpoint, query: query)
        let (data, response) = try await urlSession.data(for: request)
        let resultValue = try parse(QueryResponse<GeosearchListResponse>.self, from: data, response: response)
        guard let resultQuery = resultValue.query else {
            return []
        }
        return resultQuery.geosearch

    }
    
    /// searchWikidataItems
    /// - Parameters:
    ///   - term: `String` to search for
    ///   - languageCode: the language to search in as well as return the results (should use the user's preferred Locale)
    /// - Returns: a list of Wikidata Q-Items
    public func searchWikidataItems(term: String, languageCode: String, offset: Int? = nil) async throws -> SearchWikidataEntityResponse {
//        http://www.wikidata.org/w/api.php?action=wbsearchentities&search=test&language=en&format=json&type=item
        var query: Parameters = [
            "action": "wbsearchentities",
            "formatversion": "2",
            "language": languageCode,
            "uselang": languageCode,
            "search": term,
            "type": "item",
            "limit": "20",
            "format": "json",
            "smaxage": "3600",
            "maxage": "3600",
            "curtimestamp": "1"
        ]
        
        if let offset {
            query["continue"] = String(offset)
        }
        
        let request = try URLRequest.GET(url: wikidataEndpoint, query: query)
        let (data, response) = try await urlSession.data(for: request)
        let resultValue = try parse(SearchWikidataEntityResponse.self, from: data, response: response)
        return resultValue
    }
    
    public func fetchGenericWikidataItems(itemIDs: [String], languageCode: LanguageCode) async throws -> [GenericWikidataItem] {
        let preferredLanguages = ([languageCode] + getPreferredSystemLanguages()).uniqued().joined(separator: ",")
        let ids = itemIDs.reduce("") { partialResult, qItem in
            partialResult + " wd:\(qItem)"
        }
        let sparqlQuery = """
SELECT
(STRAFTER(STR(?item), "entity/") AS ?id)
?commonsCategory
?label
?image
?area
?location
(GROUP_CONCAT(DISTINCT STRAFTER(STR(?instance), "entity/"); separator=",") AS ?instances)
?description
WHERE {
    VALUES ?item { \(ids) }  # Q-items
    OPTIONAL { ?item wdt:P18 ?image. }
    OPTIONAL { ?item wdt:P31 ?instance. }
    OPTIONAL { ?item wdt:P625 ?location. }
    OPTIONAL { ?item wdt:P373 ?commonsCategory. }
    OPTIONAL {
        ?item p:P2046/psn:P2046 [ # area, normalised (psn retrieves the normaized value, psv the original one)
            wikibase:quantityAmount ?area;
            wikibase:quantityUnit ?areaUnit;
        ]
    }
    SERVICE wikibase:label {
        bd:serviceParam wikibase:language "\(preferredLanguages),[AUTO_LANGUAGE],mul,en,de,fr,es,it,nl".
        ?item rdfs:label ?label;
        schema:description ?description.
    }
}
GROUP BY ?item ?commonsCategory ?area ?location ?label ?image ?description
"""
        
        let query: Parameters = [
            "query": sparqlQuery,
            "format": "json"
        ]
        
        let request = try URLRequest.GET(url: wikidataSparqlEndpoint, query: query)
        let (data, response) = try await urlSession.data(for: request)
        let resultValue = try parse(SPARQLResponse<SparqlGenericWikidataItem>.self, from: data, response: response)
        
        let groupedResult = resultValue.results.bindings.map {
            GenericWikidataItem($0, language: languageCode)
        }.grouped(by: \.id)
        
        /// restore the original order
        let orderedResult: [GenericWikidataItem] = itemIDs.compactMap { id in
            guard !id.isEmpty else { return nil }
            return groupedResult[id]?.first
        }
        
        return orderedResult
    }
    
    
    /// Given a list of Q-Items ["Q42", "Q1"] etc. returns their commons categories if they are linked with both P910 (http://www.wikidata.org/entity/Property:P910)
    /// and P373 (http://www.wikidata.org/entity/Property:P373)
    // eg: https://query.wikidata.org/sparql?query=%20%20SELECT%20%3Fitem%20%3FitemLabel%20%3FcommonsCategory%20%3FcommonsCategoryLabel%20WHERE%20%7B%0A%20%20%20%20VALUES%20%3Fitem%20%7Bwd%3AQ2%20wd%3AQ5%20wd%3AQ42%20%20%7D%20%20%23%20Replace%20these%20with%20your%20Q-items%0A%20%20%20%20%3Fitem%20wdt%3AP910%20%3FcommonsCategory%20.%20%20%20%20%23%20P910%20links%20to%20the%20main%20category%0A%20%20%20%20%3FcommonsCategory%20wdt%3AP373%20%3FcommonsName%20.%20%23%20Filter%20to%20ensure%20it%20has%20a%20Commons%20category%0A%20%20%7D%0A%0A&format=json
    public func findCategoriesForWikidataItems(_ itemIDs: [String], languageCode: String) async throws -> [GenericWikidataItem] {
        let preferredLanguages = ([languageCode] + getPreferredSystemLanguages()).uniqued().joined(separator: ",")
        let ids = itemIDs.reduce("") { partialResult, qItem in
            partialResult + " wd:\(qItem)"
        }
        let sparqlQuery = """
SELECT
(STRAFTER(STR(?item), "entity/") AS ?id)
?commonsCategory
?label
?image
?area
?location
(GROUP_CONCAT(DISTINCT STRAFTER(STR(?instance), "entity/"); separator=",") AS ?instances)
?description
WHERE {
    VALUES ?item { \(ids) }  # Q-items
    OPTIONAL { ?item wdt:P18 ?image. }
    OPTIONAL { ?item wdt:P31 ?instance. }
    OPTIONAL { ?item wdt:P625 ?location. }
    OPTIONAL { ?item wdt:P373 ?commonsCategory. }
    OPTIONAL {
        ?item p:P2046/psn:P2046 [ # area, normalised (psn retrieves the normaized value, psv the original one)
            wikibase:quantityAmount ?area;
            wikibase:quantityUnit ?areaUnit;
        ]
    }
    SERVICE wikibase:label {
        bd:serviceParam wikibase:language "\(preferredLanguages),[AUTO_LANGUAGE],mul,en,de,fr,es,it,nl".
        ?item rdfs:label ?label;
        schema:description ?description.
    }
}
GROUP BY ?item ?commonsCategory ?area ?location ?label ?image ?description
"""
        
        let query: Parameters = [
            "query": sparqlQuery,
            "format": "json"
        ]
        
        let request = try URLRequest.GET(url: wikidataSparqlEndpoint, query: query)
        let (data, response) = try await urlSession.data(for: request)
        let resultValue = try parse(SPARQLResponse<SparqlGenericWikidataItem>.self, from: data, response: response)
        
        let formattedResult: [GenericWikidataItem] = resultValue.results.bindings.map {
            GenericWikidataItem($0, language: languageCode)
        }
        return formattedResult
    }
    
    
    public func findWikidataItemsForCategories(_ categories: [String], languageCode: String) async throws -> [GenericWikidataItem] {
        let preferredLanguages = ([languageCode] + getPreferredSystemLanguages()).uniqued().joined(separator: ",")
        let categoriesString = categories
            .map {
                let quotationMarksEscapedString = $0.replacing("\"", with: "\\\"")
                return "\"\(quotationMarksEscapedString)\""
            }
            .joined(separator: " ")
        
        // Find wikidata items that have matchign P373 (Commons Category
        // but We filter out instances of meta-items (ie. Q4167836) that,
        // eg. only return "Berlin Q64, but not Wikimedia-Kategorie:Berlin Q4579913,
        let sparqlQuery = """
SELECT
(STRAFTER(STR(?item), "entity/") AS ?id)
?commonsCategory
?label
?image
?area
?location
(GROUP_CONCAT(DISTINCT STRAFTER(STR(?instance), "entity/"); separator=",") AS ?instances)
?description
WHERE {
    VALUES ?commonsCategory { \(categoriesString) } ?item wdt:P373 ?commonsCategory.
    FILTER(NOT EXISTS { ?item (wdt:P31/(wdt:P279*)) wd:Q4167836. })
    OPTIONAL { ?item wdt:P18 ?image. }
    OPTIONAL { ?item wdt:P31 ?instance. }
    OPTIONAL { ?item wdt:P625 ?location. }
    OPTIONAL { ?item wdt:P373 ?commonsCategory. }
    OPTIONAL {
        ?item p:P2046/psn:P2046 [ # area, normalised (psn retrieves the normaized value, psv the original one)
            wikibase:quantityAmount ?area;
            wikibase:quantityUnit ?areaUnit;
        ]
    }
    SERVICE wikibase:label {
        bd:serviceParam wikibase:language "\(preferredLanguages),[AUTO_LANGUAGE],mul,en,de,fr,es,it,nl".
        ?item rdfs:label ?label;
        schema:description ?description.
    }
}
GROUP BY ?item ?commonsCategory ?area ?location ?label ?image ?description
"""
        
        let query: Parameters = [
            "query": sparqlQuery,
            "format": "json"
        ]
        
        let request = try URLRequest.GET(url: wikidataSparqlEndpoint, query: query)
        let (data, response) = try await urlSession.data(for: request)
        let resultValue = try parse(SPARQLResponse<SparqlGenericWikidataItem>.self, from: data, response: response)
        
        let groupedResult = resultValue.results.bindings.map {
            GenericWikidataItem($0, language: languageCode)
        }.grouped(by: \.commonsCategory)
        
        /// restore the original order
        let orderedResult: [GenericWikidataItem] = categories.compactMap { commonsCategory in
            guard !commonsCategory.isEmpty else { return nil }
            return groupedResult[commonsCategory]?.first
        }
        return orderedResult
    }
    
    // NOTE: see "radius_query_for_upload_wizard.rq" for similar query in android commons project
    public func getWikidataItemsAroundCoordinate(_ coordinate: CLLocationCoordinate2D, kilometerRadius: Double, limit: Int = 10000, minArea: Double? = nil, languageCode: LanguageCode) async throws -> [GenericWikidataItem] {
        
        let kilometerRadius = Int(kilometerRadius.rounded(.awayFromZero))
        let preferredLanguages = ([languageCode] + getPreferredSystemLanguages()).uniqued().joined(separator: ",")
        
        let minAreaFilter = if let minArea {
            "FILTER(?area > \(minArea))"
        } else {
            ""
        }
        
        // NOTE: IMPORTANT: `?distance` must remain in the query even if not used when parsing
        // because it affects the ORDER BY statement
        let sparqlQuery = """
SELECT
(STRAFTER(STR(?item), "entity/") AS ?id)
?commonsCategory
?label
?image
?area
?location
?distance
(GROUP_CONCAT(DISTINCT STRAFTER(STR(?instance), "entity/"); separator=",") AS ?instances)
?description
WHERE {
    SERVICE wikibase:around {
      ?item wdt:P625 ?location .
      bd:serviceParam wikibase:center "Point(\(coordinate.longitude) \(coordinate.latitude))"^^geo:wktLiteral .
      bd:serviceParam wikibase:radius "\(kilometerRadius)" .
      bd:serviceParam wikibase:distance ?distance .
    }
    OPTIONAL { ?item wdt:P18 ?image. }
    OPTIONAL { ?item wdt:P31 ?instance. }
    OPTIONAL { ?item wdt:P625 ?location. }
    OPTIONAL { ?item wdt:P373 ?commonsCategory. }
    \(minArea == nil  ? "OPTIONAL" : "") {
        ?item p:P2046/psn:P2046 [ # area, normalised (psn retrieves the normaized value, psv the original one)
            wikibase:quantityAmount ?area;
            wikibase:quantityUnit ?areaUnit;
        ]
        \(minAreaFilter)
    }
    SERVICE wikibase:label {
        bd:serviceParam wikibase:language "\(preferredLanguages),[AUTO_LANGUAGE],mul,en,de,fr,es,it,nl".
        ?item rdfs:label ?label;
        schema:description ?description.
    }
}
GROUP BY ?item ?commonsCategory ?location ?distance ?area ?label ?image ?description
ORDER BY ?distance LIMIT \(limit)
"""
        
        let query: Parameters = [
            "query": sparqlQuery,
            "format": "json"
        ]
        
        let request = try URLRequest.GET(url: wikidataSparqlEndpoint, query: query)
        let (data, response) = try await urlSession.data(for: request)
        let resultValue = try parse(SPARQLResponse<SparqlGenericWikidataItem>.self, from: data, response: response)
        
        let formattedResult: [GenericWikidataItem] = resultValue.results.bindings.map {
            GenericWikidataItem($0, language: languageCode)
        }
        
        return formattedResult
    }
    
    public func getWikidataItemsInBoundingBox(
        cornerSouthWest: CLLocationCoordinate2D,
        cornerNorthEast: CLLocationCoordinate2D,
        isAreaOptional: Bool,
        isCategoryOptional: Bool,
        languageCode: String,
        limit: Int = 10000
    ) async throws -> [GenericWikidataItem] {
        
        let preferredLanguages = ([languageCode] + getPreferredSystemLanguages()).uniqued().joined(separator: ",")
        
        var areaQuery = """
        ?item p:P2046/psn:P2046 [ # area, normalised (psn retrieves the normaized value, psv the original one)
            wikibase:quantityAmount ?area;
            wikibase:quantityUnit ?areaUnit;
        ]
"""
        
        var categoryQuery = "?item wdt:P373 ?commonsCategory."
        if isCategoryOptional {
            categoryQuery = "OPTIONAL { \(categoryQuery) }"
        }
        
        var orderQuery = ""
        if isAreaOptional {
            areaQuery = "OPTIONAL {\n\(areaQuery)\n}"
        } else {
            orderQuery = "ORDER BY DESC(?area)"
        }
        
        let sparqlQuery = """
SELECT DISTINCT (STRAFTER(STR(?item), "entity/") AS ?id) ?label ?description ?location ?area ?commonsCategory (GROUP_CONCAT(DISTINCT STRAFTER(STR(?instance), "entity/"); separator=",") AS ?instances) ?image WHERE {
SERVICE wikibase:box {
    ?item wdt:P625 ?location.
    bd:serviceParam wikibase:cornerSouthWest "Point(\(cornerSouthWest.longitude) \(cornerSouthWest.latitude))"^^geo:wktLiteral;
    wikibase:cornerNorthEast "Point(\(cornerNorthEast.longitude) \(cornerNorthEast.latitude))"^^geo:wktLiteral.
}

\(areaQuery)
OPTIONAL { ?item wdt:P31 ?instance. }
OPTIONAL { ?item wdt:P625 ?location. }
OPTIONAL { ?item wdt:P18 ?image. }
\(categoryQuery)
SERVICE wikibase:label {
    bd:serviceParam wikibase:language "\(preferredLanguages),[AUTO_LANGUAGE],mul,en,de,fr,es,it,nl".
    ?item rdfs:label ?label;
    schema:description ?description.
}
}
\(orderQuery)
GROUP BY ?item ?commonsCategory ?location ?label ?description ?image ?area
LIMIT \(limit)
"""
        

        let query: Parameters = [
            "query": sparqlQuery,
            "format": "json"
        ]
        
        let request = try URLRequest.GET(url: wikidataSparqlEndpoint, query: query)
        let (data, response) = try await urlSession.data(for: request)
        let resultValue = try parse(SPARQLResponse<SparqlGenericWikidataItem>.self, from: data, response: response)
        
        return resultValue.results.bindings.map {
            GenericWikidataItem($0, language: languageCode)
        }
    }
    
//    func getDepictCount() {
//"""
//SELECT ?label ?description (COUNT(*) AS ?fileCount) WHERE {
//  VALUES ?item { wd:Q1765611 wd:Q64 wd:Q183 }  # Replace with your list of Q-items
//  ?file wdt:P180 ?item .  # Find files where P180 (depicts) is the given item
//  SERVICE wikibase:label {
//    bd:serviceParam wikibase:language "en".
//    ?item rdfs:label ?label;
//    schema:description ?description.
//}
//}
//GROUP BY ?item ?itemLabel
//ORDER BY DESC(?fileCount)
//"""
//    }
    
    
    
    /// action: opensearch
    /// smaxage=30&maxage=30
    // https://commons.wikimedia.org/wiki/Special:ApiSandbox#action=opensearch&format=json&search=Adlers&namespace=6%7C0&profile=fuzzy&warningsaserror=1&formatversion=2
    public func searchSuggestedSearchTerms(for term: String, limit: ListLimit? = nil, namespaces: [MediawikiNamespace]) async throws -> [String] {
        let cacheDuration = 60 * 60 * 24 * 7 // 1 week
        
        var query: Parameters = [
            "action": "opensearch",
            "curtimestamp": "1",
            "search": term,
            "namespace": namespaces.apiString,
            "profile": "engine_autoselect",
            "format": "json",
            "smaxage": String(cacheDuration),
            "maxage": String(cacheDuration),
            "formatversion": "2",
            "warningsaserror": "1"
        ]
        
        if let limit {
            query["limit"] = limit.apiString
        }
        
        let request = try URLRequest.GET(url: commonsEndpoint, query: query)
        let (data, response) = try await urlSession.data(for: request)
        
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CommonAPIError.invalidResponseType(rawDataString: String(data: data, encoding: .utf8))
        }
        
        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [Any] else {
            throw CommonAPIError.failedToDecodeJSONArray
        }
        // This API-action returns the original search term as the first element in the result array.
        assert(
            (jsonArray[0] as? String) == term,
            "We expect the the string returned from the API to match our original search term."
        )

        if let suggestedTerms = jsonArray[1] as? [String] {
            return suggestedTerms
        } else {
            return []
        }
    }
    
    // see "snak": http://www.wikidata.org/entity/Wikidata:Glossary
    // https://commons.wikimedia.org/w/api.php?action=wbgetentities&format=json&curtimestamp=1&sites=commonswiki&titles=File%3AThe_Earth_seen_from_Apollo_17.jpg&redirects=yes&props=info%7Clabels%7Cclaims&languages=&sitefilter=&callback=&formatversion=2
    /// Returns a dictionary of entities where the key is the wikibase formatted pageID (string with "M" suffix), eg. "M148014716" for pageID 148014716.
    public func fetchStructuredData(_ identifiers: FileIdentifierList) async throws -> [String: WikidataFileEntity] {
        // NOTE: In contrast to Q-Items and Properties (P) where only limited language translations are fetched,
        // for files we don't want a reduced language set when calling "wbgetentities" for easier editing.
        
        var query: Parameters = [
            "action": "wbgetentities",
            "curtimestamp": "1",
            "sites": "commonswiki",
            "exportschema": "0.11",
            "formatversion": "2",
            "smaxage": "60",
            "maxage": "60",
            "format": "json"
        ]
        
        switch identifiers {
        case .titles(let titles):
            query["titles"] = titles.joined(separator: "|")
        case .pageids(let pageids):
            query["ids"] = pageids.map{ "M\($0)" }.joined(separator: "|")
        }
        
        let request = try URLRequest.GET(url: commonsEndpoint, query: query)
        let (data, response) = try await urlSession.data(for: request)
        let entitiesDict = try parse(FileEntitiesResponse.self, from: data, response: response).entities
        return entitiesDict
    }
    
    /// Check if a media file already exists on Wikimedia Commons by its filename
    /// - Parameter filename: The filename to check (without the "File:" prefix)
    /// - Returns: `true` if the file exists, `false` otherwise
    public func checkIfFileExists(filename: String) async throws -> Bool {
        let query: Parameters = [
            "action": "query",
            "format": "json",
            "titles": "File:" + filename,
            "formatversion": "2",
            "curtimestamp": "1"
        ]

        let request = try URLRequest.GET(url: commonsEndpoint, query: query)
        let (data, response) = try await urlSession.data(for: request)
        let parsedResponse = try parse(QueryResponse<FileExistenceResponse>.self, from: data, response: response)
        guard let fileInfo = parsedResponse.query?.pages?.first else {
            throw CommonAPIError.missingResponseValues
        }
        let isMissing = fileInfo.missing ?? false
        return !isMissing
    }

    /// Returns the labels for Wikidata ids, which can be either WikidataProperties ("P180" etc.) or WikidataEntityIds ("Q1" etc.)
    /// for each id a dictionary is returned with language code keys.
    /// eg.: ["P180":  ["en": "depicted"]]
    public typealias LanguageCode = String
    public func fetchWikidataEntities(ids: [String], preferredLanguages: [String]) async throws ->  [String: GenericWikidataItem] {
        guard !preferredLanguages.isEmpty, let preferredLanguage = preferredLanguages.first else {
            assertionFailure()
            throw CommonAPIError.missingLanguageCodes
        }
        
        let query: Parameters = [
            "action": "wbgetentities",
            "curtimestamp": "1",
            "props": "labels|descriptions|info",
            "languages": preferredLanguages.joined(separator: "|"),
            /// languagefallback will return fitting translations even if the preferredLanguage doesn't perfectly match so that there is
            /// always some label proper
            "languagefallback": "1",
            "ids": ids.joined(separator: "|"),
            "formatversion": "2",
            "smaxage": "60",
            "maxage": "60",
            "format": "json"
        ]
        
        let request = try URLRequest.GET(url: wikidataEndpoint, query: query)
        let (data, response) = try await urlSession.data(for: request)
        let responseValue = try parse(EntitiesResponse.self, from: data, response: response)
        
        let result: [String: GenericWikidataItem] = responseValue.entities.mapValues { entity in
            
            let requestedID: String
            let redirectID: String?
            
            if let redirects = entity.redirects {
                logger.info("Redirect:  Found an item that redirects to another one (eg. after a merge)")
                // NOTE: we cannot use the returned entity ID as the main-ID because that one already
                // contains the resolved ID
                requestedID = redirects.from
                redirectID = redirects.to
            } else {
                requestedID = entity.id
                redirectID = nil
            }
            
            
            return GenericWikidataItem(
                commonsCategory: nil,
                id: requestedID,
                redirectsToId: redirectID,
                label: entity.labels.values.first,
                description: entity.descriptions.values.first,
                labelLanguage: preferredLanguage,
                instances: [],
                latitude: nil,
                longitude: nil,
                area: nil,
                image: nil
            )
        }
        return result

    }
    
    
    /// https://commons.wikimedia.org/w/api.php?action=upload&format=json&filename=&comment=&file=...&stash=1&token=&formatversion=2
    public func publish(file: MediaFileUploadable, csrfToken: String) -> AsyncStream<UploadStatus> {
        // Thanks to Donny Wals for this informative blog post on multipart requests with URLSession:
        // https://www.donnywals.com/uploading-images-and-forms-to-a-server-using-urlsession/
        
        AsyncStream<UploadStatus> { continuation in
            Task<Void, Never> {
                do {
                    var parameters: Parameters = [
                        "action": "upload",
                        "token": csrfToken,
                        "filename": file.filename,
                        "comment": uploadComment,
                        "text": file.wikiText,
                        "stash": "1",
                        "formatversion": "2",
                        "format": "json"
                    ]
                    
                    let request = try URLRequest.POSTMultipart(
                        url: commonsEndpoint,
                        fileURL: file.fileURL,
                        filename: file.filename,
                        params: parameters
                    )

                    let progressDelegate = UploadProgressDelegate { progress in
                        continuation.yield(.uploadingFile(progress))
                    }

                    let (data, response) = try await urlSession.data(for: request, delegate: progressDelegate)
                    let fileUploadResponse = try parse(FileUploadResponse.self, from: data, response: response)
                    let responseValue = fileUploadResponse.upload
                    
                    guard responseValue.warnings.isEmpty else {
                        continuation.yield(.uploadWarnings(responseValue.warnings))
                        continuation.finish()
                        return
                    }
                    
                    // All uploads done and claims created, un-stash the file
                    parameters.removeValue(forKey: "stash")
                    parameters["filekey"] = responseValue.filekey
                    
                    continuation.yield(.unstashingFile)
                    let unstashRequest = try URLRequest.POST(url: commonsEndpoint, form: parameters)
                    let unstashResult = try await urlSession.data(for: unstashRequest)
                    logger.debug("action:upload result string:\n\(String(data: unstashResult.0, encoding: .utf8) ?? "?")")
                    
                    // NOTE: Structured Data can only be created after the file is public/unstashed
                    // Thats why we do it here and not before unstashing.
                    try await editStructuredDataEntity(
                        title: "File:\(file.filename)",
                        labels: file.captions,
                        statements: file.claims,
                        comment: nil
                    )

                    continuation.yield(.published)
                    continuation.finish()
                } catch {
                    logger.error("Failed uploading a file \(error)")
                    continuation.yield(.unspecifiedError(error))
                    continuation.finish()
                }
            }
        }
    }


    /// action: wbeditentity
    func editStructuredDataEntity(title: String, labels: [LanguageString], statements: [WikidataClaim], comment: String?) async throws {
        let token = try await fetchCSRFToken()
        
        struct EditStructuredDataRequestBody: Encodable {
            var labels: [String: LanguageValue]?
            var claims: [WikidataClaim]?
        }
        
        var dataField = EditStructuredDataRequestBody()
        
        if !labels.isEmpty {
            dataField.labels = [:]
            for label in labels {
                dataField.labels?[label.languageCode] = .init(forLanguage: nil, language: label.languageCode, value: label.string)
            }
        }
        
        if !statements.isEmpty {
            dataField.claims = statements
        }
        
        let data = try JSONEncoder().encode(dataField)
        guard let dataString = String(data: data, encoding: .utf8) else {
            throw CommonAPIError.failedToEncodeJSONData
        }
        
        let commentString: String
        
        if let comment {
            commentString = comment
        } else if !labels.isEmpty, !statements.isEmpty {
            commentString = "Edited labels (\(labels.map(\.languageCode).joined(separator: ", "))) and structured data statements"
        } else if labels.isEmpty {
            commentString = "Edited structured data statements"
        } else if statements.isEmpty {
            commentString = "Edited labels (\( labels.map(\.languageCode).joined(separator: ", ")))"
        } else {
            commentString = "Edited labels or structured data statements"
            assertionFailure()
        }

        let form: Parameters = [
            "action": "wbeditentity",
            "comment": commentString,
            "token": token,
            "format": "json",
            "title": title,
            "site": "commonswiki",
            "data": dataString,
            "formatversion": "2",
            "clear": "true"
        ]
        
        let request = try URLRequest.POST(url: commonsEndpoint, form: form)
        let (dataOut, response) = try await urlSession.data(for: request)
        // Log response string for debugging, but don't fail hard if decoding isn't set up.
        if let responseString = String(data: dataOut, encoding: .utf8) {
            logger.debug("wbeditentity response: \(responseString)")
        } else {
            logger.debug("wbeditentity response (non-utf8, status: \((response as? HTTPURLResponse)?.statusCode ?? -1))")
        }
    }
}

internal extension [MediawikiNamespace] {
    /// returns the pipe-joined string: [.file, .main] -> "file|main"
    var apiString: String {
        self
            .map { String($0.rawValue) }
            .joined(separator: "|")
    }
}

private func getPreferredSystemLanguages() -> [LanguageCode] {
    return if #available(iOS 26.0, *) {
        Locale.preferredLocales.compactMap { locale in
            locale.language.languageCode?.identifier
        }
    } else {
        Locale.preferredLanguages
    }
}
