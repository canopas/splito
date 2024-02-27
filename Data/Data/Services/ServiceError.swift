//
//  ServiceError.swift
//  Data
//
//  Created by Amisha Italiya on 26/02/24.
//

import Foundation

// MARK: - Errors
public enum ServiceError: LocalizedError, Equatable {
    case none
    case unauthorized
    case serverError(statusCode: Int? = nil)
    case networkError
    case validationFailed

    public var descriptionText: String {
        switch self {
        case .none:
            return ""
        case .unauthorized:
            return "You are an unauthorised user."
        case .serverError(let statusCode):
            return "Server error encountered."
        case .networkError:
            return "No internet connection!"
        default:
            return "Oops"
        }
    }

    public var key: String {
        switch self {
        case .none:
            return "none"
        case .unauthorized:
            return "unauthorized"
        case .networkError:
            return "networkError"
        case .serverError:
            return "serverError"
        case .validationFailed:
            return "validationFailed"
        }
    }
}
