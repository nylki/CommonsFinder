//
//  Date+RawRepresentable.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 16.06.26.
//

import Foundation

extension Date: @retroactive RawRepresentable {
    public typealias RawValue = String

    public init?(rawValue: RawValue) {
        guard let data = rawValue.data(using: .utf8),
            let date = try? JSONDecoder().decode(Date.self, from: data)
        else {
            return nil
        }
        self = date
    }

    public var rawValue: RawValue {
        guard let data = try? JSONEncoder().encode(self),
            let result = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return result
    }
}
