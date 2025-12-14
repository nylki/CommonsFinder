//
//  TokenType.swift
//  CommonsAPI
//
//  Created by Tom Brewe on 13.12.25.
//


enum TokenType: CustomStringConvertible {
    case login
    case createAccount
    case csrf
    
    var description: String {
        switch self {
        case .login:
            "login"
        case .createAccount:
            "createaccount"
        case .csrf:
            "csrf"
        }
    }
}
