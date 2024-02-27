//
//  Country.swift
//  Data
//
//  Created by Amisha Italiya on 23/02/24.
//

import Foundation

// MARK: - Country
public struct Country: Codable, Identifiable {
    public let id = UUID().uuidString
    public let name: String
    public let dialCode: String
    public let isoCode: String
    
    public init(name: String, dialCode: String, isoCode: String) {
        self.name = name
        self.dialCode = dialCode
        self.isoCode = isoCode
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case dialCode = "dial_code"
        case isoCode = "code"
    }
    
    public var flag: String {
        return String(String.UnicodeScalarView(
            isoCode.unicodeScalars.compactMap({ UnicodeScalar(127397 + $0.value) })))
    }
}
