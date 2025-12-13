//
//  UserAgent.swift
//  CommonsAPI
//
//  Created by Tom Brewe on 19.10.24.
//

import Foundation

let osNameVersion: String = {
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

// Preferred format for User-Agent headers for wikimedia prohects (see: https://www.mediawiki.org/wiki/API:Etiquette#The_User-Agent_header)
// <client name>/<version> (<contact information>) <library/framework name>/<version>

/// Adapted from Alamofire's default `User-Agent` header.
///
/// See the [User-Agent header documentation](https://tools.ietf.org/html/rfc7231#section-5.5.3).
///
let userAgent: String = {
    let info = Bundle.main.infoDictionary
    let executable = (info?["CFBundleExecutable"] as? String) ??
    (ProcessInfo.processInfo.arguments.first?.split(separator: "/").last.map(String.init)) ??
    "Unknown"
    let bundle = info?["CFBundleIdentifier"] as? String ?? "Unknown"
    let appVersion = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
    let appBuild = info?["CFBundleVersion"] as? String ?? "Unknown"
    
    let contactInfo = "https://github.com/nylki/CommonsFinder"
    
    let userAgent = "\(executable)/\(appBuild) (\(contactInfo)) \(osNameVersion)"
    
    return userAgent
}()


let uploadComment: String = {
    let info = Bundle.main.infoDictionary
    let executable = (info?["CFBundleExecutable"] as? String) ??
    (ProcessInfo.processInfo.arguments.first?.split(separator: "/").last.map(String.init)) ??
    "Unknown"
    let bundle = info?["CFBundleIdentifier"] as? String ?? "Unknown"
    let appVersion = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
    let appBuild = info?["CFBundleVersion"] as? String ?? "Unknown"
    
    return "uploaded from \(executable)/\(appBuild) \(osNameVersion)"
}()
