//
//  ServiceError.swift
//  Data
//
//  Created by Amisha Italiya on 26/02/24.
//

import Foundation

// MARK: - Errors
public enum ServiceError: LocalizedError {
    case decodingError
    case databaseError(error: Error)
    case unexpectedError
    case dataNotFound

    public var descriptionText: String {
        switch self {
        case .databaseError(let error):
            return "\(error.localizedDescription)"
        case .decodingError, .unexpectedError:
            return "Something went wrong."
        case .dataNotFound:
            return "Your requested data not found."
        }
    }

    public var key: String {
        switch self {
        case .databaseError:
            return "databaseError"
        case .decodingError:
            return "decodingError"
        case .unexpectedError:
            return "unexpectedError"
        case .dataNotFound:
            return "dataNotFound"
        }
    }
}
