//
//  CookieStorage+helpers.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 09.02.26.
//

import Foundation

extension HTTPCookieStorage {
    // NOTE: These helpers are more or less directly from the Wikipedia iOS app, see for reference.

    func cloneCentralAuthCookies() {
        // centralauth_ cookies work for any central auth domain - this call copies the centralauth_* cookies from .wikipedia.org to an explicit list of domains. This is  hardcoded because we only want to copy ".wikipedia.org" cookies regardless of WMFDefaultSiteDomain
        copyCookiesWithNamePrefix("centralauth_", for: Domain.centralAuthCookieSourceDomain, to: Domain.centralAuthCookieTargetDomains)
    }

    func cookiesWithNamePrefix(_ prefix: String, for domain: String) -> [HTTPCookie] {
        guard let cookies, !cookies.isEmpty else {
            return []
        }
        let standardizedPrefix = prefix.lowercased().precomposedStringWithCanonicalMapping
        let standardizedDomain = domain.lowercased().precomposedStringWithCanonicalMapping
        return cookies.filter { cookie in
            cookie.domain.lowercased().precomposedStringWithCanonicalMapping == standardizedDomain && cookie.name.lowercased().precomposedStringWithCanonicalMapping.hasPrefix(standardizedPrefix)
        }
    }

    func cookieWithName(_ name: String, for domain: String) -> HTTPCookie? {
        guard let cookies, !cookies.isEmpty else {
            return nil
        }
        let standardizedName = name.lowercased().precomposedStringWithCanonicalMapping
        let standardizedDomain = domain.lowercased().precomposedStringWithCanonicalMapping
        return
            cookies.filter { cookie in
                cookie.domain.lowercased().precomposedStringWithCanonicalMapping == standardizedDomain && cookie.name.lowercased().precomposedStringWithCanonicalMapping == standardizedName
            }
            .first
    }

    func copyCookiesWithNamePrefix(_ prefix: String, for domain: String, to toDomains: [String]) {
        let cookies = cookiesWithNamePrefix(prefix, for: domain)
        for toDomain in toDomains {
            for cookie in cookies {
                var properties = cookie.properties ?? [:]
                properties[.domain] = toDomain
                guard let copiedCookie = HTTPCookie(properties: properties) else {
                    continue
                }
                setCookie(copiedCookie)
            }
        }
    }
}
