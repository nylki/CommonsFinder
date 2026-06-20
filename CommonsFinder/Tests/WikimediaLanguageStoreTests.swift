//
//  WikimediaLanguageStoreTests.swift
//  CommonsFinderTests
//
//  Created by Tom Brewe on 20.06.26.
//

import Foundation
import Testing

@Suite("WikimediaLanguageStoreTests")
struct WikimediaLanguageStoreTests {

    let store = WikimediaLanguageStore()

    @Test(
        "Loading a bundled or downloaded language JSON file",
        .disabled("needs implementation")
    )
    func testLoading() {

    }

    @Test(
        "saving a language JSON file",
        .disabled("needs implementation")
    )
    func testSaving() {

    }
}
