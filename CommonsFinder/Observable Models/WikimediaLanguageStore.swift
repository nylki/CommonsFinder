//
//  WikimediaLanguageStore.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 17.06.26.
//

import CommonsAPI
import Foundation
import os.log

// see API sandbox:
// https://commons.wikimedia.org/wiki/Special:ApiSandbox#action=query&format=json&meta=wbcontentlanguages&formatversion=2&wbclcontext=term&wbclprop=code%7Cautonym%7Cname

typealias LanguageDictionary = [String: WikimediaLanguage]

enum WikimediaLanguageStoreError: Error {
    case failedToConstructFilePath
}

@Observable final class WikimediaLanguageStore {
    // code:language
    var languages: LanguageDictionary
    private var downloadTask: Task<Void, Never>?


    private static let bundledLanguagesPath: URL? = {
        guard let url = Bundle.main.url(forResource: "languages", withExtension: "json") else {
            assertionFailure("We expect to always have this language json file.")
            return nil
        }
        return url
    }()

    private static let downloadedLanguagesPath: URL? =
        FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)
        .first?
        .appending(path: "/Languages")

    private static var downloadedLanguageFilePaths: [URL] {
        guard let downloadedLanguagesPath else { return [] }

        do {
            let paths = try FileManager.default.contentsOfDirectory(at: downloadedLanguagesPath, includingPropertiesForKeys: nil)
            return paths
        } catch {
            logger.error("Failed to list contents of downloaded languages directory \(error)")
            return []
        }
    }

    private static func pathForJSON(forLanguageCode languageCode: String) -> URL? {
        downloadedLanguagesPath?.appending(path: "/languages_\(languageCode).json")
    }

    private static func loadJSON(url: URL) -> LanguageDictionary? {
        guard FileManager.default.fileExists(atPath: url.path()) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let jsonData = try decoder.decode([String: WikimediaLanguage].self, from: data)
            return jsonData
        } catch {
            logger.error("error loading json:\(error)")
            return nil
        }
    }

    private static func saveJSON(languages: LanguageDictionary, languageCode: String) throws {
        guard let downloadedLanguagesPath else {
            assertionFailure()
            return
        }

        try? FileManager.default.createDirectory(at: downloadedLanguagesPath, withIntermediateDirectories: true)

        guard let outputPath = pathForJSON(forLanguageCode: languageCode) else {
            throw WikimediaLanguageStoreError.failedToConstructFilePath
        }

        let encoder = JSONEncoder()
        let json = try encoder.encode(languages)
        try json.write(to: outputPath)
    }

    private static func deleteDownloadedLanguages() {
        guard let downloadedLanguagesPath,
            let existingLanguageFiles = try? FileManager.default.contentsOfDirectory(at: downloadedLanguagesPath, includingPropertiesForKeys: nil)
        else {
            return
        }

        for path in existingLanguageFiles {
            do {
                try FileManager.default.removeItem(at: path)
            } catch {
                logger.warning("Failed to delete language json file \(path.absoluteString)")
            }
        }
    }

    init() {
        // First we check if there is a downloaded localized language json.


        let preferredLanguageCode = Locale.LanguageCode.preferredLanguageCodes.first ?? .english

        let result: LanguageDictionary

        if let loadedLanguages = Self.loadInputLanguages(for: preferredLanguageCode) {
            result = loadedLanguages
        } else if let anyLoadedLanguages = Self.loadAnyInputLanguages() {
            result = anyLoadedLanguages
        } else if let bundledLanguages = Self.loadBundledInputLanguages() {
            result = bundledLanguages
        } else {
            if ProcessInfo.isRunningInPreview {
                result = [
                    "en": .init(code: "en", autonym: "English", name: nil),
                    "yyy": .init(code: "te", autonym: "Test Language (Running in Preview)", name: "Preview Test Language"),
                ]
            } else {
                assertionFailure("We always expect to have language JSON files (downloaded or bundled) if not running in a Preview.")
                result = [:]
            }


        }

        self.languages = result
        self.downloadTask = nil
    }


    private static func loadInputLanguages(for languageCode: Locale.LanguageCode) -> LanguageDictionary? {
        if let pathForLanguageCode = Self.pathForJSON(forLanguageCode: languageCode.identifier),
            let loadedLanguages = Self.loadJSON(url: pathForLanguageCode)
        {
            loadedLanguages
        } else {
            nil
        }
    }

    private static func loadAnyInputLanguages() -> LanguageDictionary? {
        if let anyDownloadedLanguagePath = downloadedLanguageFilePaths.first,
            let loadedLanguages = Self.loadJSON(url: anyDownloadedLanguagePath)
        {
            loadedLanguages
        } else {
            nil
        }
    }

    private static func loadBundledInputLanguages() -> LanguageDictionary? {
        if let bundledLanguagesPath,
            let loadedLanguages = Self.loadJSON(url: bundledLanguagesPath)
        {
            loadedLanguages
        } else {
            nil
        }
    }


    func loadOrDownloadInputLanguages(for languageCode: Locale.LanguageCode) {
        downloadTask?.cancel()

        if let existing = Self.loadInputLanguages(for: languageCode) {
            self.languages = existing
            return
        }

        downloadTask = Task<Void, Never> {
            let languageCode = languageCode.identifier
            defer { downloadTask = nil }

            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                logger.debug("Debounced language JSON download for 1 second \(error)")
                return
            }

            do {
                let fetchedLanguages = try await Networking.shared.api.fetchContentLanguages(localizedFor: languageCode)

                guard !fetchedLanguages.isEmpty, fetchedLanguages.count > 100, fetchedLanguages["en"] != nil else {
                    assertionFailure("Fetched language list is incomplete or wrongly decoded \(fetchedLanguages.debugDescription)")
                    return
                }

                let languages: LanguageDictionary = fetchedLanguages.mapValues { .init(apiValue: $0) }

                try Self.saveJSON(languages: languages, languageCode: languageCode)

                self.languages = languages
            } catch {
                logger.error("Failed to update languages \(error)")
            }
        }
    }

    func query(_ string: String) -> [WikimediaLanguage] {
        let matchingLanguages: [WikimediaLanguage] =
            if string.isEmpty {
                Array(languages.values)
            } else {
                languages.values.filter {
                    $0.code.localizedStandardContains(string) || ($0.name ?? "").localizedStandardContains(string) || ($0.autonym ?? "").localizedStandardContains(string)
                }
            }

        return matchingLanguages.sorted(by: \.code, .orderedAscending)
    }

    /// based on system settings in iOS
    var preferredLanguages: [WikimediaLanguage] {
        var preferredLanguages = Locale.LanguageCode.preferredLanguageCodes.compactMap { code in
            languages[code.identifier]
        }
        if preferredLanguages.isEmpty, let english = languages["en"] {
            logger.warning("No preferred language matched with the JSON file use english fallback.")
            preferredLanguages.append(english)
        }
        return preferredLanguages
    }
}

extension WikimediaLanguage {
    fileprivate init(apiValue: CommonsAPI.WikimediaLanguage) {
        self = .init(
            code: apiValue.code,
            autonym: apiValue.autonym,
            name: apiValue.name
        )
    }
}
