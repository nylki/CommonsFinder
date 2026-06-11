//
//  Keychain+Username.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 08.06.26.
//

import SwiftSecurity
import os.log

//nonisolated extension WebProtectionSpace {
//    fileprivate static let wikimedia: Self = .website("wikimedia.org")
//}

nonisolated extension SecItemQuery<GenericPassword> {
    /// Username as String
    static var activeUser: Self {
        .credential(for: "activeUser")
    }
    static var login: Self {
        .credential(for: "login")
    }
}

extension Keychain {
    /// retrieves the active username and also makes sure a password is in keychain for that username
    func retrieveActiveUsername() throws -> String? {
        guard let username: String = try retrieve(.activeUser) else {
            logger.debug("retrieveActiveUsername: ❌ does not exists")
            return nil
        }
        return username
    }

    /// retrieves the active username and also makes sure a password is in keychain for that username
    func storeActiveUsername(_ username: String) throws {
        if try info(for: .activeUser) != nil {
            try remove(.activeUser)
        }
        try store(username, query: .activeUser)
    }
}
