import Testing
import UniformTypeIdentifiers
import os.log
import SwiftUI
@testable import CommonsAPI


// End-to-End-Tests

/// These are End-to-End-Tests and **make actual network calls** to the Wikimedia Commons API,
/// so **be mindful** how often and with what parameters you run them!
/// NOTE: Some tests require credentials DO NOT COMMIT CREDENTIALS AFTER TESTING
@Suite("Commons E2E Tests", .serialized)
struct CommonsEndToEndTests {
    let logger = Logger(subsystem: "CommonsAPITests", category: "E2E")
    
    let api: CommonsAPI.API = {
        let info = Bundle.main.infoDictionary
        let executable = (info?["CFBundleExecutable"] as? String) ?? (ProcessInfo.processInfo.arguments.first?.split(separator: "/").last.map(String.init)) ?? "Unknown"
        let bundle = info?["CFBundleIdentifier"] as? String ?? "Unknown"
        let appVersion = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let appBuild = info?["CFBundleVersion"] as? String ?? "Unknown"

        let contactInfo = "https://github.com/nylki/CommonsFinder"

        let userAgent = "\(executable)/\(appBuild) (\(contactInfo)) \(osNameVersion)"
        return CommonsAPI.API(userAgent: userAgent, referer: "CommonsFinder://UnitTests")
    }()

    @Test("login and fetching CSRF-token",
          // comment out the next line to test login with valid credentials
          .disabled("Requires a valid password"),
          arguments: [(username: "", password: "DO NOT COMMIT CREDENTIALS AFTER TESTING")]
    )
    func loginAndFetchCSRFToken(username: String, password: String) async throws {
        let status = try await api.login(username: username, password: password)
        try #require(status.status == .pass)
        
        let csrfToken = try await api.fetchCSRFToken()
        #expect(!csrfToken.isEmpty)
    }
    
    @Test("list user uploads", arguments: ["Flickr_upload_bot"])
    func listUserUploads(username: String) async throws {
        let titles = try await api.listUserImages(
            of: username,
            limit: .count(1),
            start: nil,
            end: nil,
            direction: .older,
            continueString: nil
        )
        .titles
        
        print(titles)
        #expect(!titles.isEmpty)
    }
    
    
    @Test("search categories", arguments: ["Earth", "test", "امتحان", "测试", "テスト", "土", "п"])
    func searchCategories(term: String) async throws {
        let items = try await api.searchCategories(for: term).items
        print(items)
        #expect(!items.isEmpty, "We expect to get results for this search term")
    }
    
    @Test("list full-metadata files by search term")
    func searchFiles() async throws {
        let searchResults = try await api.searchFiles(for: "test")
        // print(searchResults)
        #expect(!searchResults.items.isEmpty, "We expect to get results for this search term")
        #expect(searchResults.items.allSatisfy { $0.ns == .file }, "We expect that all results to be in the `file` mediawiki namespace.")
    }
    
    @Test("search suggestions (fast prefix matching search)", arguments: ["test", "a", "ü", "Ü", "امتحان", "测试", "テスト", "土", "п"])
    func searchSuggestions(searchTerm: String) async throws {
        let searchSuggestions = try await api.searchSuggestedSearchTerms(for: searchTerm, namespaces: [.category, .main, .file])
        print(searchSuggestions)
        #expect(!searchSuggestions.isEmpty, "We expect to get results for this search term")
    }
    
    @Test("get wikidata statements", arguments: ["File:The Earth seen from Apollo 17.jpg"])
    func fetchStructuredDataForMedia(title: String) async throws {
        let statements = try await api.fetchStructuredData(.titles([title]))
        print(statements)
        #expect(!statements.isEmpty, "We expect to get results for this search term")
    }
    
    @Test("get label and description for Q-Item",
          arguments: [
            (["Q1", "Q2"], ["en", "de"]),
            (["Q42"], ["en", "de-formal"]),
            (["Q4321"], ["vo"]),
        ]
    )
    
    func fetchWikidataLabels(ids: [String], languages: [String]) async throws {
        let entities = try await api.fetchWikidataEntities(ids: ids, preferredLanguages: languages)
        print(entities)
        #expect(!entities.isEmpty)
        let responseIDs = entities.keys
        #expect(Set(ids) == Set(responseIDs), "We expect to get all (and only) translations for the given ids")
    }
    
    @Test("uploading files",
          // comment out the next line to test uploading with valid credentials
          .disabled("Requires a valid password"),
          arguments: [(username: "", password: "DO NOT COMMIT CREDENTIALS AFTER TESTING")]
    )
    func canUploadFiles(username: String, password: String) async throws {
        let fileManager = FileManager.default
        
        let sampleJpegData = UIGraphicsImageRenderer(
            size: .init(width: Int.random(in: 500..<1000), height: Int.random(in: 500..<1000))
        ).image { ctx in
            [UIColor.purple, UIColor.green, UIColor.gray, UIColor.black].randomElement()!.setFill()
            ctx.fill(.init(origin: .init(
                x: Int.random(in: 0..<250),
                y: Int.random(in: 0..<250)),
                size: .init(width: Int.random(in: 0..<250), height: Int.random(in: 0..<250))
            ))
        }
            .jpegData(compressionQuality: Double.random(in: 0.5..<0.95))
        
        let pathURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, conformingTo: .jpeg)
        
        fileManager.createFile(atPath: pathURL.path(), contents: sampleJpegData)
        try #require(
            fileManager.fileExists(atPath: pathURL.path()),
            "File must exist before uploading"
        )
        
        try await confirmation("Confirm that the upload finishes") { confirmation in
            _ = try await api.login(username: username, password: password)
            let csrfToken = try await api.fetchCSRFToken()
            
            
            let mainSnak = WikidataClaim.Snak.init(snaktype: "value", property: WikidataProp(intValue: 180), datavalue: .wikibaseEntityID(.Q(4115189)))
            let claims = [WikidataClaim(mainsnak: mainSnak)]
            
            
            let wikitext = """
=={{int:filedesc}}==
{{Information
|description={{en
|This is a test file for a new Wikimedia-Commons client. This file can be deleted (but please wait an 1 hour)}}
|date=\(Date.now.ISO8601Format())
|source={{own}}
|author=[[CommonsFinderTester|CommonsFinderTester]]
|permission=
|other versions=
}}
            
=={{int:license-header}}==
{{self|cc-by-4.0}}

{{test upload}}

"""
            let mediaFileUploadable = MediaFileUploadable(
                id: UUID().uuidString,
                fileURL: pathURL,
                filename: "iOS Client upload testing image \(UUID().uuidString) \(Date.now.formatted(date: .complete, time: .omitted)).jpg",
                mimetype: UTType.jpeg.preferredMIMEType!,
                claims: claims,
                captions: [
                    .init("This is a test file testing the upload in a new Wikimedia-Commons client. This file can be deleted (but please wait an 1 hour)", languageCode: "en"),
                    .init("Dies ist eine Testdatei um den File-Upload einer neuen Wikimedia-Commons App zu testen. Kann gelöscht werden (aber bitte 1h warten)", languageCode: "de")
                ],
                wikitext: wikitext
            )
            
            for await progress in await api.publish(file: mediaFileUploadable, csrfToken: csrfToken) {
                switch progress {
                case .uploadingFile(let progress):
                    logger.debug("upload progress: \(100 * progress.fractionCompleted)%")
                case .published:
                    logger.debug("upload finished")
                    confirmation()
                case .uploadWarnings(let warnings):
                    for warning in warnings {
                        logger.error("upload error \(warning.description)")
                    }
                case .creatingWikidataClaims:
                    logger.debug("creatingWikidataClaims")
                case .unstashingFile:
                    logger.debug("unstashFile")
                case .unspecifiedError(let error):
                    logger.debug("unspecifiedAPIError \(error)")
                case .fileKeyObtained(filekey: let filekey):
                    logger.debug("fileKeyObtained filekey \(filekey)")
                case .fileKeyMissingAfterUpload:
                    logger.debug("fileKeyMissingAfterUpload")
                case .urlError(let error):
                    logger.debug("urlError \(error.localizedDescription)")
                }
            }
        }
        
        print("Finished upload test")
    }
    
    @Test("list sub-categories", arguments: ["Physics"])
    func fetchCategoryInfo(category: String) async throws {
        let info = try await api.fetchCategoryInfo(of: category)
        
        #expect(info != nil)
        guard let info else { return }
        
        #expect(info.parentCategories.count > 0)
        #expect(info.subCategories.count > 5)
        #expect(info.wikidataItem  == .physicsCategory)
    }
    
    @Test("list images in category", arguments: ["Physics"])
    func listImagesInCategory(category: String) async throws {
        let results = try await api.listCategoryImagesRaw(of: category)
        #expect(results.files.count > 5)
    }
    
//    @Test("edit structured data",
//          // comment out the next line to test uploading with valid credentials
//          .disabled("Requires a valid password"),
//          arguments: [(username: "", password: "DO NOT COMMIT CREDENTIALS AFTER TESTING")]
//    )
//    func testEditStructuredData(title: String, labels: [String: String], statements: [WikidataClaim]) async throws {
//        try await CommonsAPI.api.editStructuredData(title: title, labels: labels, statements: statements)
//    }

    @Test("check if file exists", arguments: [
        (filename: "The_Earth_seen_from_Apollo_17.jpg", expected: FilenameExistsResult.exists),
        (filename: "This_file_should_not_exist_12345.jpg", expected: FilenameExistsResult.doesNotExist),
        (filename: "[invalid<>].jpg", expected: FilenameExistsResult.invalidFilename),
    ])
    func checkIfFileExists(filename: String, expectedValue: FilenameExistsResult) async throws {
        let result = try await api.checkIfFileExists(filename: filename)
        #expect(result == expectedValue)
    }
    
    @Test("validate filename and check if filename is on blacklist", arguments: [
        (filename: "This is a perfectly valid filename 2025-01-01.jpg", expected: FilenameValidationStatus.ok),
        (filename: "File:20191208 205403-VideoToMp4(1).webm", expected: FilenameValidationStatus.disallowed),
        (filename: "File:this is invalid because {of} brackets", expected: FilenameValidationStatus.invalid),
    ])
    func validateFilename(filename: String, expectedResponse: FilenameValidationStatus) async throws {
        let response = try await api.validateFilename(filename: filename)
        #expect(response == expectedResponse)
    }
    
    
}


