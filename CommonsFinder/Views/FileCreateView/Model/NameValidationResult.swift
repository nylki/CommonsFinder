//
//  NameValidationResult.swift
//  CommonsFinder
//
//  Created by Tom Brewe on 25.03.26.
//


typealias NameValidationResult = Result<Void, NameValidationError>

extension NameValidationResult {
    var error: NameValidationError? {
        switch self {
        case .success: return nil
        case .failure(let error): return error
        }
    }

    var alertTitle: String? {
        if let error {
            switch error {
            case .invalid(_):
                error.failureReason
            default:
                error.errorDescription
            }
        } else {
            nil
        }
    }
}
