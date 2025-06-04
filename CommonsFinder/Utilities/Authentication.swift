//
//  Authentication.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 14.11.24.
//

import CommonsAPI
import Foundation
import SwiftSecurity
import os.log

// NOTE: CSRF-Token not stored currently, but refetched for each request

// NOTE: https://developer.apple.com/documentation/security/shared-web-credentials
// (most likely!) only works if associated domains can be setup (requires a file hosted on wikimedia.org domain
// so will have to keep using a bit less convenient keychain store for the time being.
// see also: https://developer.apple.com/documentation/security/managing-shared-credentials


enum AuthenticationResponseError: Error {
    case captchaInfoMissing
}

/// Namespace for handling Network authentication in combination with keychain handling
enum Authentication {}

extension WebProtectionSpace {
    fileprivate static let wikimedia: Self = .website("wikimedia.org")
}

extension SecItemQuery<GenericPassword> {
    fileprivate static var activeUser: Self {
        .credential(for: "activeUser")
    }
}

extension SecItemQuery<InternetPassword> {
    fileprivate static func password(forUser username: String) -> Self {
        .credential(for: username, space: .wikimedia)
    }
}

extension Authentication {

    static func clearKeychain() throws {
        try Keychain.default.removeAll(includingSynchronizableCredentials: false)
    }

    /// retrieves the active username and also makes sure a password is in keychain for that username
    static func retrieveActiveUsername() throws -> String? {
        guard let username: String = try Keychain.default.retrieve(.activeUser) else {
            logger.debug("retrieveActiveUsername: ❌ does not exists")
            return nil
        }

        let passwordInfo = try Keychain.default.info(for: .password(forUser: username))

        guard passwordInfo != nil else {
            logger.debug(
                "retrieveActiveUsername: ⚠️ exists. But no corresponding password stored, this is unexpected because both items are saved. Removing `activeUsername` keychain item to have a clean slate."
            )
            try Keychain.default.remove(.activeUser)
            assertionFailure("Error retrieving active username: it does exist, but the password does not!")
            return nil
        }
        logger.debug("retrieveActiveUsername: ✅ exists and corresponding password as well!")
        return username
    }

    static func loginUsingKeychain(forUsername username: String) async throws(AuthError) {
        let password: String?

        do {
            password = try Keychain.default.retrieve(.password(forUser: username))
        } catch {
            throw .keychainOther(error)
        }

        guard let password else {
            throw .keychainPasswordMissing(username: username)
        }
        // We don't want to store the password again, as we just succesfully retrieved it.
        try await Authentication.login(username: username, password: password, storingCredentials: false)
    }

    /// Authenticates with the API and if succeeded will securely store the credentials in the keychain
    /// for future authentications without user interaction.
    static func login(username: String, password: String, storingCredentials: Bool = true) async throws(AuthError) {
        let response: LoginResponse
        do {
            response = try await API.shared.login(username: username, password: password)
        } catch {
            throw .network(error)
        }

        switch response.status {
        case .fail:
            throw .authenticationFailedOther(response.messagecode)
        case .ui, .redirect, .restart:
            throw .authenticationAdditionalSteps(response.status.rawValue)
        case .pass:
            let keychain = Keychain.default

            do {

                // Remove creds if they already exist and log it for debgging
                let activeUserWasAlreadyStored = try keychain.remove(.activeUser)
                let passwordWasAlreadyStored = try keychain.remove(.password(forUser: username))

                if activeUserWasAlreadyStored {
                    logger.debug("duplicate key found during login: activeUsername")
                }
                if passwordWasAlreadyStored {
                    logger.debug("duplicate key found during login: password for \(username, privacy: .private)")
                }


                try keychain.store(password, query: .password(forUser: username))
                try keychain.store(username, query: .activeUser)
            } catch let error as SwiftSecurityError {
                switch error {

                default:
                    throw .keychainOther(error)
                }

            } catch {
                throw .keychainOther(error)
            }
        }
    }

    struct TokenAndCaptchaURL {
        let token: String
        let captchaID: String
        let captchaURL: URL
    }

    static func fetchCreateAccountTokenAndCaptchaInfo() async throws -> TokenAndCaptchaURL {
        let info = try await API.shared.fetchCreateAccountInfo()
        guard let captchaURL = info.captchaURL, let captchaID = info.captchaID else {
            throw AuthenticationResponseError.captchaInfoMissing
        }
        return .init(token: info.token, captchaID: captchaID, captchaURL: captchaURL)
    }

    static func validateUsernamePassword(username: String, password: String, email: String) async throws -> UsernamePasswordValidation {
        let validation = try await API.shared.validateUsernamePassword(username: username, password: password, email: email)
        return validation
    }


    static func createAccount(
        username: String,
        password: String,
        email: String,
        captchaWord: String,
        captchaID: String,
        token: String,
        storingCredentials: Bool = true
    ) async throws(AuthError) {
        let response: CreateAccountResponse
        do {
            response = try await API.shared.createAccount(
                usingCreateAccountToken: token,
                captchaWord: captchaWord,
                captchaID: captchaID,
                username: username,
                password: password,
                email: email
            )
        } catch {
            throw .network(error)
        }

        switch response.status {
        case .fail:
            // Looking at messagecode to determine why it failed and return more a specific
            // error where it is useful for the auth or register flow.
            switch response.messagecode {
            case .captchaCreateAccountFail:
                throw .captchaFailed
            case .accountCreationThrottleHit:
                throw .accountCreationThrottleLimit
            default:
                throw .authenticationFailedOther(response.messagecode?.localizedDescription)
            }
        case .ui, .redirect, .restart:
            throw .authenticationAdditionalSteps(response.message ?? "unknown")
        case .pass:
            let keychain = Keychain.default

            do {

                // Remove creds if they already exist and log it for debgging
                let activeUserWasAlreadyStored = try keychain.remove(.activeUser)
                let passwordWasAlreadyStored = try keychain.remove(.password(forUser: username))

                if activeUserWasAlreadyStored {
                    logger.debug("duplicate key found during login: activeUsername")
                }
                if passwordWasAlreadyStored {
                    logger.debug("duplicate key found during login: password for \(username, privacy: .private)")
                }

                try keychain.store(password, query: .password(forUser: username))
                try keychain.store(username, query: .activeUser)
            } catch let error as SwiftSecurityError {
                switch error {

                default:
                    throw .keychainOther(error)
                }

            } catch {
                throw .keychainOther(error)
            }
        }
    }

    /// Fetches the CSRF-token from the API for edit/upload actions
    /// Will re-login with keychain credentials if necessary.

    static func fetchCSRFToken() async throws(AuthError) -> String {
        do {
            return try await API.shared.fetchCSRFToken()
        } catch {
            return try await retryFetchingCSRFToken()
        }
    }

    static private func retryFetchingCSRFToken() async throws(AuthError) -> String {
        // Check keychain and retry by logging in again
        // We expect to find credentials as they are securely stored on a succesful login.
        let activeUsername: String

        do {
            guard let retrievedString = try retrieveActiveUsername() else {
                throw AuthError.keychainActiveUsernameMissing
            }
            activeUsername = retrievedString
        } catch {
            throw AuthError.keychainOther(error)
        }

        try await loginUsingKeychain(forUsername: activeUsername)
        return try await fetchCSRFToken()
    }
}

extension Authentication {
    // TODO: maybe differentiate between Login and Create Errors?
    enum AuthError: LocalizedError {
        /// lower level network error (timeout, bad gateway etc.)
        case network(Error)
        case captchaFailed
        /// credentials are not valid
        case accountCreationThrottleLimit
        case authenticationFailedOther(String?)
        /// auth requires addition steps (redirect, ui, restart)
        case authenticationAdditionalSteps(String)

        case keychainActiveUsernameMissing
        case keychainPasswordMissing(username: String)
        case keychainOther(Error)

        var errorDescription: String? {
            switch self {
            case .network(let error):
                "Network error during authentication: \(error.localizedDescription)"
            case .captchaFailed:
                "The provided captcha was not accepted"
            case .accountCreationThrottleLimit:
                "Too many accounts registered in the last 24h via your current IP address."
            case .authenticationFailedOther(let string):
                "authentication failed. \(string ?? "unknown reason.")"
            case .authenticationAdditionalSteps(let string):
                "authentication was not succesful because it requires additional steps (UI, RESTART). details: \(string)"
            case .keychainActiveUsernameMissing:
                "The active username was not found in kechain."
            case .keychainPasswordMissing(let username):
                "The password associated with user \(username) was not found"
            case .keychainOther(let error):
                "keychain error: \(error.localizedDescription)"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .accountCreationThrottleLimit:
                "Try again later or from a different network."
            case .captchaFailed:
                "Try again."
            default:
                "Try again later."
            }
        }

        var helpAnchor: String? {
            switch self {
            case .accountCreationThrottleLimit:
                "Wikimedia Commons has a policy to limit the signup attempts per IP address, per day. You unfortunately appear to have hit this limit. If you are in a public network or at an event this could be a reason."
            default: nil
            }
        }
    }

    private struct WikimediaCredentials {
        let username: String
        let password: String
    }
}
