//
//  Date+WikidataCompatibleDateString.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 05.02.25.
//

import Foundation

extension Date {
    /// This is an ISO-8601 Date String that only correcly encodes the date component
    /// all time components are set to 0, the timezone is _incorrectly_ set to UTC (Z).
    /// Unfortunately this format is required for Wikidata dates.
    /// eg: +2025-01-19T00:00:00Z instead of +2025-01-19T20:21:22Z
    var dateOnlyWikidataCompatibleISOString: String {
        let dateComponent = ISO8601Format(.iso8601.year().month().day())
        let timezoneOffset = "Z"
        return "+\(dateComponent)T00:00:00\(timezoneOffset)"
    }
}
