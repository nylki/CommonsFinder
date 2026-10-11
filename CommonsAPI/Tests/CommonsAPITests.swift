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
    

    static var responseProvider: APIResponseProvider {
        { request, requiresAuthentication in
            try await URLSession.shared.data(for: request)
        }
    }
    
    let api: CommonsAPI.API = {
        let info = Bundle.main.infoDictionary
        let executable = (info?["CFBundleExecutable"] as? String) ?? (ProcessInfo.processInfo.arguments.first?.split(separator: "/").last.map(String.init)) ?? "Unknown"
        let bundle = info?["CFBundleIdentifier"] as? String ?? "Unknown"
        let appVersion = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let appBuild = info?["CFBundleVersion"] as? String ?? "Unknown"

        let contactInfo = "https://github.com/nylki/CommonsFinder"

        let userAgent = "\(executable)/\(appBuild) (\(contactInfo)) \(osNameVersion)"
        return CommonsAPI.API(config: .default, responseProvider: responseProvider, tokenProvider: { return "" }, userAgent: userAgent, referer: "commonsfinder://UnitTests")
    }()
    
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
        let statements = try await api.fetchMediaFileStructuredData(.titles([title]))
        print(statements)
        #expect(!statements.isEmpty, "We expect to get results for this search term")
    }
    
    @Test("list sub-categories", arguments: ["Physics"])
    func fetchCategoryInfo(category: String) async throws {
        let info = try await api.fetchCategoryMembers(of: category, sort: nil)
        
        #expect(info != nil)
        guard let info else { return }
        
        #expect(info.parentCategories.count > 0)
        #expect(info.subCategories.count > 5)
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
        // this one will be normalized, has an extra space:
        (filename: "", expected: FilenameExistsResult.invalidFilename),
        (filename: "006 Toco toucan in Encontro das Águas State Park Photo by  Giles Laurent.jpg", expected: FilenameExistsResult.exists),
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


