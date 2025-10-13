//
//  URL+resizedCommonsImageURL.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 14.03.25.
//

import CryptoKit
import Foundation
import RegexBuilder
import os.log

enum ResizeCommonsImageURLError: Error {
    /// The provided URL is not in a format known to be a fullsize image on Wikimedia Commons
    case unknownImageURL(URL)
    case invalidConstructedURL(String)
    case urlDecodingError
}

nonisolated
    extension URL
{
    func resizedCommonsImageURL(maxWidth: Int) throws -> URL {
        // from: https://upload.wikimedia.org/wikipedia/commons/2/2c/Image_Title.jpg
        // to:   https://upload.wikimedia.org/wikipedia/commons/thumb/2/2c/Image_Title.jpg/320px-Image_Title.jpg

        guard absoluteString.starts(with: "https://upload.wikimedia.org/wikipedia"),
            pathComponents.count >= 5
        else {
            logger.warning("The provided URL (\(self.absoluteString)) is not in a format known to be a fullsize image on Wikimedia Commons")
            throw ResizeCommonsImageURLError.unknownImageURL(self)
        }
        /// either "commons" or "en" or something else.
        let base = pathComponents[2]

        let hashA = pathComponents[3]
        let hashB = pathComponents[4]
        let title = pathComponents[5]
        let hashAndTitle = "\(hashA)/\(hashB)/\(title)"

        let urlString = "https://upload.wikimedia.org/wikipedia/\(base)/thumb/\(hashAndTitle)/\(maxWidth)px-\(title)"
        guard let thumbURL = URL(string: urlString) else {
            throw ResizeCommonsImageURLError.invalidConstructedURL(urlString)
        }
        return thumbURL
    }

    /// This function returns a commons image URL from a filename, assuming the known usage of the MD5 prefixes.
    /// NOTE: MARKED AS EXPERIMENTAL
    static func experimentalResizedCommonsImageURL(filename: String, maxWidth: UInt) throws -> URL {
        let normalizedFilename = filename.replacing(.whitespace, with: "_")
        guard let data = normalizedFilename.data(using: .utf8) else {
            throw ResizeCommonsImageURLError.urlDecodingError
        }
        let hash = Insecure.MD5.hash(data: data).map { String(format: "%02hhx", $0) }.joined()
        let hashA = hash.prefix(1)
        let hashB = hash.prefix(2)
        let hashAndTitle = "\(hashA)/\(hashB)/\(normalizedFilename)"

        // Base is unknown, assume "commons"
        let base = "commons"
        let urlString = "https://upload.wikimedia.org/wikipedia/\(base)/thumb/\(hashAndTitle)/\(maxWidth)px-\(normalizedFilename)"
        guard let thumbURL = URL(string: urlString) else {
            throw ResizeCommonsImageURLError.invalidConstructedURL(urlString)
        }
        return thumbURL
    }
}
