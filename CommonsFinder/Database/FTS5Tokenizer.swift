//
//  FTS5Tokenizer.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 01.11.24.
//

import Foundation
import GRDB

final class LatinAsciiTokenizer: FTS5WrapperTokenizer {
    static let name = "latinascii"
    let wrappedTokenizer: any FTS5Tokenizer

    init(db: Database, arguments: [String]) throws {
        wrappedTokenizer = try db.makeTokenizer(.unicode61())
    }

    func accept(token: String, flags: FTS5TokenFlags, for tokenization: FTS5Tokenization, tokenCallback: FTS5WrapperTokenCallback) throws {

        // This is an ICU format transliteration rule
        // https://unicode-org.github.io/icu/userguide/transforms/general/#icu-transliterators
        // For some examples see this insightful blog post:
        // https://bartvanraaij.dev/2020-10-17-converting-utf8-strings-to-ascii-using-icu-transliterator/
        let transform = StringTransform("Any-Latin; Latin-ASCII; Lower")

        if let token = token.applyingTransform(transform, reverse: false) {
            try tokenCallback(token, flags)
        }
    }
}
