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
    case decodingError
    case databaseError(error: String)
    case unexpectedError
    case validationFailed
    case dataNotFound
    case alreadyExists
    case deleteFailed(error: String)

    public var descriptionText: String {
        switch self {
        case .none:
            return ""
        case .unauthorized:
            return "You are an unauthorised user."
        case .serverError:
            return "Server error encountered."
        case .networkError:
            return "No internet connection!"
        case .databaseError:
            return "Failed to perform database operation."
        case .decodingError:
            return "Couldn't decode the response."
        case .unexpectedError:
            return "Something went wrong."
        case .dataNotFound:
            return "Your requested data not found."
        case .alreadyExists:
            return "Sorry, we can not perform your request as the data is already exists."
        case .deleteFailed(let error):
            return error
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
        case .databaseError:
            return "databaseError"
        case .decodingError:
            return "decodingError"
        case .unexpectedError:
            return "unexpectedError"
        case .validationFailed:
            return "validationFailed"
        case .dataNotFound:
            return "dataNotFound"
        case .alreadyExists:
            return "alreadyExists"
        case .deleteFailed:
            return "deleteFailed"
        }
    }
}
