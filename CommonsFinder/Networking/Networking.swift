//
//  Networking.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 25.01.26.
//

import AuthenticationServices
import CommonsAPI
import Foundation
import Nuke
import OAuthenticator
import Pulse
import SwiftSecurity
import os.log

enum URLResponseProviderError: Error {
    case missingResponseComponents
}

enum NetworkingError: Error {
    case couldNotFindOAuthClientIdInEnvironment
}

actor Networking {
    static let shared: Networking = .init()

    var api: API { lazyAPI ?? rebuildAPI() }

    private(set) var referer: String
    let userAgent: String
    let editAndUploadCommentSuffix: String
    let uploadComment: String
    let config: URLSessionConfiguration

    private var lazyAPI: API?

    private var authenticator: Authenticator

    /// this is set to `true` if the user succesfully authenticated once.
    /// It will never reset to `false`. On logout a new Network.shared instance is supposed to be created.
    private var assumeLoggedInUser = false

    #if DEBUG
        let urlSession: URLSessionProxy
    #else
        let urlSession: URLSession
    #endif


    private var authenticatedResponseProvider: URLResponseProvider {
        authenticator.responseProvider
    }

    private var oauthTokenProvider: OAuthTokenProvider {
        { try await self.authenticator.authenticate().accessToken.value }
    }

    private var apiResponseProvider: APIResponseProvider {
        { request, requiresAuthentication in
            let assumeLoggedInUser = await self.assumeLoggedInUser
            if requiresAuthentication || assumeLoggedInUser {
                return try await self.authenticatedResponseProvider(request)
            } else {
                return try await self.urlSession.responseProvider(request)
            }
        }
    }


    private static var oauthClientID: String {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "OAUTH_CLIENT_ID") as? String, !clientID.isEmpty else {
            fatalError(
                "The clientId for OAuth must be present in the Config for the app to function properly. See Debug.xcconfig. `Release.xcconfig` will get its value automatically from XCode Cloud variables via `ce_pre_xcodebuild`"
            )
        }
        return clientID
    }

    private static var oauthClientPassword: String {
        // NOTE: non-confidential clients must not use client passwords to authenticate.
        // For that reason, DANGEROUS_OAUTH_CLIENT_PASSWORD will remain empty by default.
        // This variable exists purely for local testing with the DEBUG scheme.

        #if DEBUG
            return (Bundle.main.object(forInfoDictionaryKey: "DANGEROUS_OAUTH_CLIENT_PASSWORD") as? String) ?? ""
        #else
            return ""
        #endif
    }

    init() {
        assumeLoggedInUser = (try? Keychain.default.info(for: .activeUser)) != nil
        referer = "commonsfinder://Home"

        let info = Bundle.main.infoDictionary
        let executable = (info?["CFBundleExecutable"] as? String) ?? (ProcessInfo.processInfo.arguments.first?.split(separator: "/").last.map(String.init)) ?? "Unknown"
        //        let bundle = info?["CFBundleIdentifier"] as? String ?? "Unknown"
        //        let appVersion = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let appBuild = info?["CFBundleVersion"] as? String ?? "Unknown"

        let contactInfo = "https://github.com/nylki/CommonsFinder"

        userAgent = "\(executable)/\(appBuild) (\(contactInfo)) \(osNameVersion)"
        editAndUploadCommentSuffix = "\(executable)/\(appBuild) \(osNameVersion)"
        uploadComment = "uploaded from \(editAndUploadCommentSuffix)"

        let config = Self.buildSessionsConfig(userAgent: userAgent, initialReferer: referer)
        self.config = config

        #if DEBUG
            let urlSession = URLSessionProxy(configuration: config)
        #else
            let urlSession = URLSession(configuration: config)
        #endif

        self.urlSession = urlSession

        self.authenticator = Self.buildAuthenticator(with: urlSession.responseProvider)
    }

    @discardableResult
    private func rebuildAPI() -> API {
        let api = API(config: config, responseProvider: apiResponseProvider, tokenProvider: oauthTokenProvider, userAgent: userAgent, referer: referer)
        lazyAPI = api
        configureImagePipeline()
        return api
    }

    // Nuke ImagePipeline setup and configuration
    private func configureImagePipeline() {
        var pipelineConfig = ImagePipeline.Configuration.withDataCache(
            name: "app.CommonsFinder.DataCache",
            sizeLimit: 1024 * 1024 * 256
        )
        ImageCache.shared.costLimit = 1024 * 1024 * 512  // 512 MB
        ImageCache.shared.ttl = 60 * 10  // Invalidate images in memory cache after 10 minutes

        // configures a rate limiter that complies with the strict server-site rate limiting
        // for non-authenticated clients, which is max 10 requests in a 10s sliding window.
        pipelineConfig.rateLimiterConfig = .init(interval: 10, maxRequestCount: 10)
        let dataLoader = DataLoader(configuration: config)

        /// TESTING NOTE: If tests fail in Pulse package, comment out the following block and try again.
        #if DEBUG
            ImagePipeline.Configuration.isSignpostLoggingEnabled = true
            dataLoader.delegate = URLSessionProxyDelegate()
        #endif

        pipelineConfig.dataLoader = dataLoader
        let pipeline = ImagePipeline(configuration: pipelineConfig, delegate: self)

        ImagePipeline.shared = pipeline
    }


    func logoutAndClearKeychain() async {
        assumeLoggedInUser = false
        for cookie in HTTPCookieStorage.shared.cookies ?? [] {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
        do {
            try Keychain.default.removeAll(includingSynchronizableCredentials: true)
        } catch {
            assertionFailure("We expect to be able to remove keychain items on logout/reset. \(error)")
        }
        self.authenticator = Self.buildAuthenticator(with: urlSession.responseProvider)
        rebuildAPI()
    }

    static func buildSessionsConfig(userAgent: String, initialReferer: String) -> URLSessionConfiguration {
        let urlSessionConfig = URLSessionConfiguration.default
        urlSessionConfig.httpShouldSetCookies = true
        urlSessionConfig.httpCookieAcceptPolicy = .always
        urlSessionConfig.httpAdditionalHeaders = [
            "User-Agent": userAgent,
            // NOTE: this is just the initial referer, will be updated via setReferer().
            "Referer": initialReferer,
        ]
        return urlSessionConfig
    }

    static func buildAuthenticator(with responseProvider: @escaping URLResponseProvider) -> Authenticator {
        let appCredential = AppCredentials(
            clientId: oauthClientID,
            clientPassword: oauthClientPassword,
            scopes: [],
            callbackURL: URL(string: "commonsfinder://oauthcallback")!
        )

        let authenticationStatusHandler: Authenticator.AuthenticationStatusHandler = { result in
            #if DEBUG
                switch result {
                case .success(_):
                    logger.debug("authentication: SUCCESS")
                case .failure(let error):
                    logger.debug("authentication: FAILURE \(error)")
                }
            #endif
        }

        let loginStorage = LoginStorage(
            retrieveLogin: {
                guard let data = try Keychain.default.retrieve(.login) else {
                    return nil
                }
                let login = try JSONDecoder().decode(Login.self, from: data)
                // logger.debug("LoginStorage retrieve: accesstoken: \(login.accessToken.value) \n\nrefreshtoken: \(login.refreshToken?.value ?? "-")")
                return login
            },
            storeLogin: { login in
                do {
                    // logger.debug("LoginStorage store: accesstoken: \(login.accessToken.value) \n\nrefreshtoken: \(login.refreshToken?.value ?? "-")")
                    try Keychain.default.remove(.login)
                    try Keychain.default.store(login, query: .login)
                } catch {
                    switch error as? SwiftSecurityError {
                    case .duplicateItem:
                        logger.error("duplicate keychain key \(error)")
                        fatalError("Failed to store OAuth token (duplicate key error)")
                    default:
                        // unhandled
                        logger.error("Failed to store oauth2 token. \(error)")
                        assertionFailure("Failed to store oauth2 token. \(error)")
                        _ = try? Keychain.default.remove(.login)
                    }
                }
            })

        let authConfig = Authenticator.Configuration(
            appCredentials: appCredential,
            loginStorage: loginStorage,
            tokenHandling: MediaWikiOAuth.tokenHandling(serverConfig: .init(host: "commons.wikimedia.org")),
            mode: .automatic,
            userAuthenticator: ASWebAuthenticationSession.userAuthenticator,
            authenticationStatusHandler: authenticationStatusHandler
        )
        return Authenticator(config: authConfig, urlLoader: responseProvider)
    }

    @discardableResult
    func authenticate() async throws -> Login {
        let login = try await authenticator.authenticate()
        if !assumeLoggedInUser, login.accessToken.valid, login.refreshToken?.valid == true {
            assumeLoggedInUser = true
        }
        return login
    }


    func setReferer(_ newReferer: String) {
        referer = newReferer
        Task<Void, Never> {
            await api.setReferer(newReferer)
        }
    }
    // Preferred format for User-Agent headers for wikimedia prohects (see: https://www.mediawiki.org/wiki/API:Etiquette#The_User-Agent_header)
    // <client name>/<version> (<contact information>) <library/framework name>/<version>

    /// Adapted from Alamofire's default `User-Agent` header.
    ///
    /// See the [User-Agent header documentation](https://tools.ietf.org/html/rfc7231#section-5.5.3).
    ///
    private let osNameVersion: String = {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        let osName: String = {
            #if os(iOS)
                #if targetEnvironment(macCatalyst)
                    return "macOS(Catalyst)"
                #else
                    return "iOS"
                #endif
            #elseif os(watchOS)
                return "watchOS"
            #elseif os(tvOS)
                return "tvOS"
            #elseif os(macOS)
                #if targetEnvironment(macCatalyst)
                    return "macOS(Catalyst)"
                #else
                    return "macOS"
                #endif
            #elseif swift(>=5.9.2) && os(visionOS)
                return "visionOS"
            #elseif os(Linux)
                return "Linux"
            #elseif os(Windows)
                return "Windows"
            #elseif os(Android)
                return "Android"
            #else
                return "Unknown"
            #endif
        }()

        return "\(osName) \(versionString)"
    }()
}

extension Networking: ImagePipeline.Delegate {
    func willLoadData(for request: ImageRequest, urlRequest: URLRequest, pipeline: ImagePipeline) async throws -> URLRequest {
        var urlRequest = urlRequest
        urlRequest.setValue(referer, forHTTPHeaderField: "Referer")

        if assumeLoggedInUser, urlRequest.url?.host?.hasSuffix("wikimedia.org") == true {
            let login = try await authenticate()
            urlRequest.setValue("Bearer \(login.accessToken.value)", forHTTPHeaderField: "Authorization")
        }
        return urlRequest
    }
}

public typealias URLResponseProviderWithDelegate = @Sendable (URLRequest, URLSessionTaskDelegate) async throws -> (Data, URLResponse)

// responseProvider: extending URLSessionProtocol to support Pulse logging.
// effectively it's just a copy of the responseProvider of the URLSession extension in OAuthenticator.
nonisolated extension URLSessionProtocol {
    public var responseProvider: URLResponseProvider {
        return { request in
            return try await withCheckedThrowingContinuation { continuation in
                let task = self.dataTask(with: request) { data, response, error in
                    switch (data, response, error) {
                    case (let data?, let response?, nil):
                        continuation.resume(returning: (data, response))
                    case (_, _, let error?):
                        continuation.resume(throwing: error)
                    case (_, _, nil):
                        continuation.resume(throwing: URLResponseProviderError.missingResponseComponents)
                    }
                }

                task.resume()
            }
        }
    }

    public var responseProviderWithDelegate: URLResponseProviderWithDelegate {
        return { request, delegate in
            return try await self.data(for: request, delegate: delegate)
        }
    }
}


nonisolated extension Login: @retroactive SecDataConvertible {
    public init<D>(rawRepresentation data: D) throws where D: ContiguousBytes {
        let fetchedData = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            let contiguousBytes = bytes.bindMemory(to: UInt8.self)
            return Data(contiguousBytes)
        }
        self = try JSONDecoder().decode(Login.self, from: fetchedData)
    }

    public var rawRepresentation: Data {
        let data = try? JSONEncoder().encode(self)
        if data == nil {
            fatalError("SecDataConvertible: rawRepresentation")
        }
        return data ?? Data()
    }
}
