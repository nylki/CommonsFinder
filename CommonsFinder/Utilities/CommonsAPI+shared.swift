//
//  CommonsAPI+shared.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 29.12.25.
//

import CommonsAPI

nonisolated extension API {
    nonisolated static let shared: API = .init(userAgent: UserAgentUtil.userAgent)
}
