import Foundation
import OAuthenticator
import os.log

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public nonisolated enum MediaWikiOAuth {
    static let scheme: String = "https"
    static let authorizePath: String = "/w/rest.php/oauth2/authorize"
    static let tokenPath: String = "/w/rest.php/oauth2/access_token"
    static let profilePath: String = "/w/rest.php/oauth2/resource/profile"

    static let grantTypeAuthorizationCode: String = "authorization_code"
    static let grantTypeRefreshToken: String = "refresh_token"

    private static let jsonDecoder = JSONDecoder()

    struct ServerConfig: Sendable {
        let host: String
    }

    struct AuthLoginResponse: Codable, Hashable, Sendable {
        let accessToken: String
        let expiresIn: Int
        let refreshToken: String
        let tokenType: String


        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case expiresIn = "expires_in"
            case refreshToken = "refresh_token"
            case tokenType = "token_type"
        }

        var login: Login {
            Login(
                accessToken: .init(value: accessToken, expiresIn: expiresIn),
                refreshToken: .init(value: refreshToken))
        }
    }

    struct AuthAPIErrorResponse: Error, Codable, Hashable, Sendable, CustomStringConvertible {
        var error: String
        var errorDescription: String?
        var hint: String?

        enum CodingKeys: String, CodingKey {
            case error
            case errorDescription = "error_description"
            case hint
        }

        var description: String {
            "Error authenticating via OAuth2 (Wikimedia): \(error), errorDescription: \(errorDescription ?? "-") Hint: \(hint ?? "-")"
        }
    }

    struct RefreshTokenRequest: Hashable, Sendable, Codable {
        public let refresh_token: String
        public let redirect_uri: String
        public let grant_type: String
        public let client_id: String

        public init(refresh_token: String, redirect_uri: String, grant_type: String, client_id: String) {
            self.refresh_token = refresh_token
            self.redirect_uri = redirect_uri
            self.grant_type = grant_type
            self.client_id = client_id
        }
    }

    public struct UserTokenParameters: Sendable {
        public let state: String?
        public let login: String?
        public let allowSignup: Bool?

        public init(state: String? = nil, login: String? = nil, allowSignup: Bool? = nil) {
            self.state = state
            self.login = login
            self.allowSignup = allowSignup
        }
    }

    static func tokenHandling(serverConfig: ServerConfig, with parameters: UserTokenParameters = .init()) -> TokenHandling {
        TokenHandling(
            authorizationURLProvider: authorizationURLProvider(serverConfig: serverConfig, with: parameters),
            loginProvider: loginProvider(serverConfig: serverConfig),
            refreshProvider: refreshProvider(serverConfig: serverConfig),
            pkce: PKCEVerifier()
        )
    }

    static func authorizationURLProvider(serverConfig: ServerConfig, with parameters: UserTokenParameters) -> TokenHandling.AuthorizationURLProvider {
        return { params in

            let credentials = params.credentials

            var urlBuilder = URLComponents()

            urlBuilder.scheme = scheme
            urlBuilder.host = serverConfig.host
            urlBuilder.path = authorizePath
            urlBuilder.queryItems = [
                URLQueryItem(name: "grant_type", value: grantTypeAuthorizationCode),
                URLQueryItem(name: "client_id", value: credentials.clientId),
                URLQueryItem(name: "redirect_uri", value: credentials.callbackURL.absoluteString),
                URLQueryItem(name: "scope", value: credentials.scopeString),
                URLQueryItem(name: "response_type", value: "code"),
            ]

            if let pkceChallenge = params.pcke?.challenge {
                urlBuilder.queryItems?.append(URLQueryItem(name: "code_challenge_method", value: pkceChallenge.method))
                urlBuilder.queryItems?.append(URLQueryItem(name: "code_challenge", value: pkceChallenge.value))
            }

            if let state = parameters.state {
                urlBuilder.queryItems?.append(URLQueryItem(name: "state", value: state))
            }

            guard let url = urlBuilder.url else {
                throw AuthenticatorError.missingAuthorizationURL
            }

            return url
        }
    }
    static func authenticationRequest(serverConfig: ServerConfig, redirectURL: URL, appCredentials: AppCredentials, pkceVerifier: PKCEVerifier?) throws -> URLRequest {
        let code = try redirectURL.authorizationCode

        var urlBuilder = URLComponents()

        urlBuilder.host = serverConfig.host
        urlBuilder.scheme = scheme
        urlBuilder.path = tokenPath

        var form: [String: String] = [
            "grant_type": grantTypeAuthorizationCode,
            "client_id": appCredentials.clientId,
            "client_secret": appCredentials.clientPassword,
            "redirect_uri": appCredentials.callbackURL.absoluteString,
            "code": code,
        ]

        if let pkceVerifier {
            form["code_challenge_method"] = pkceVerifier.challenge.method
            form["code_challenge"] = pkceVerifier.challenge.value
            form["code_verifier"] = pkceVerifier.verifier
        }

        guard let url = urlBuilder.url else {
            throw AuthenticatorError.missingTokenURL
        }

        var request = URLRequest(url: url)
        request.httpBody = formURLEncode(form)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    @Sendable
    static func loginProvider(serverConfig: ServerConfig) -> TokenHandling.LoginProvider {
        return { params in
            let request = try authenticationRequest(
                serverConfig: serverConfig,
                redirectURL: params.redirectURL,
                appCredentials: params.credentials,
                pkceVerifier: params.pcke
            )

            let (data, _) = try await params.responseProvider(request)
            let utf8 = String(data: data, encoding: .ascii)

            do {
                let response = try jsonDecoder.decode(AuthLoginResponse.self, from: data)
                return response.login
            } catch let decodingError as DecodingError {
                if let apiError = try? jsonDecoder.decode(AuthAPIErrorResponse.self, from: data) {
                    throw apiError
                }
                throw decodingError
            } catch {
                throw error
            }
        }
    }

    /// Token Refreshing
    /// - Create the request that will refresh the access token from the information in the Login
    ///
    /// - Parameters:
    ///   - login: The current Login object containing the refresh token
    ///   - appCredentials: The Application credentials
    /// - Returns: The URLRequest to refresh the access token
    static func authenticationRefreshRequest(serverConfig: ServerConfig, login: Login, appCredentials: AppCredentials) throws -> URLRequest {
        guard let refreshToken = login.refreshToken?.value, !refreshToken.isEmpty else {
            throw AuthenticatorError.missingRefreshToken
        }

        var urlBuilder = URLComponents()

        urlBuilder.scheme = scheme
        urlBuilder.host = serverConfig.host
        urlBuilder.path = tokenPath

        guard let url = urlBuilder.url else {
            throw AuthenticatorError.missingTokenURL
        }


        let form: [String: String] = [
            "refresh_token": refreshToken,
            "redirect_uri": appCredentials.callbackURL.absoluteString,
            "grant_type": grantTypeRefreshToken,
            "client_id": appCredentials.clientId,
        ]

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = formURLEncode(form)

        return request
    }

    @Sendable
    static func refreshProvider(serverConfig: ServerConfig) -> TokenHandling.RefreshProvider {
        return { login, appCredentials, urlLoader in

            let request = try authenticationRefreshRequest(serverConfig: serverConfig, login: login, appCredentials: appCredentials)
            let (data, _) = try await urlLoader(request)

            do {
                let response = try jsonDecoder.decode(AuthLoginResponse.self, from: data)
                return response.login
            } catch let decodingError as DecodingError {
                if let apiError = try? jsonDecoder.decode(AuthAPIErrorResponse.self, from: data) {
                    throw apiError
                }
                throw decodingError
            } catch let urlError as URLError {
                switch urlError.code {
                case .notConnectedToInternet, .cannotLoadFromNetwork, .networkConnectionLost:
                    logger.notice("! Tried to refresh with no internet connection. Treat as recoverable and return the old login for now.")
                    return login
                default:
                    throw urlError
                }
            }
        }
    }

}


// Wikimedia expects some POST requests to be form url encoded for some reason, (regular url + query params don't in some cases)
// encode to application/x-www-form-urlencoded
private nonisolated func formURLEncode(_ form: [String: String]) -> Data {
    // NOTE: cannot use URLQueryItem encoding, as there are differences (eg. no "?" for the first kv-pair, only "&"s.
    var allowed = CharacterSet.urlQueryAllowed
    allowed.remove(charactersIn: ":#[]@!$&'()*+,;=")  // reserved characters that must be percent-encoded in this context

    let pairs: [String] =
        form.map { key, value in
            let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let vEncoded =
                value
                .addingPercentEncoding(withAllowedCharacters: allowed)?
                .replacing("%20", with: "+")
                ?? value.replacing(" ", with: "+")
            return "\(k)=\(vEncoded)"
        }
        .sorted()

    return pairs.joined(separator: "&").data(using: .utf8) ?? Data()
}
