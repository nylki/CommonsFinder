//
//  CommonAPIError.swift
//  CommonsAPI
//
//  Created by Tom Brewe on 13.12.25.
//


enum CommonAPIError: Error {
    case invalidResponseType(rawDataString: String?)
    case invalidQueryParams
    
    /// Requested token type not found in response
    case requestedTokenTypeMissing(TokenType)
    /// Token is too short, most likely because of no authenticated session
    case tokenTooShort(TokenType)
    
    case httpError(statusCode: Int)
    case failedToDecodeJSONArray
    case failedToEncodeJSONData
    case missingLanguageCodes
    case missingResponseValues
}
