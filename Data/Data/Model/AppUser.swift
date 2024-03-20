//
//  AppUser.swift
//  Data
//
//  Created by Amisha Italiya on 26/02/24.
//

import Foundation

public struct AppUser: Identifiable, Equatable, Codable {

    public static func == (lhs: AppUser, rhs: AppUser) -> Bool {
        return lhs.id == rhs.id
    }

    public var id: String
    public var firstName: String?
    public var lastName: String?
    public var emailId: String?
    public let phoneNumber: String?
    public let imageUrl: String?
    public let loginType: LoginType

    public init(id: String, firstName: String?, lastName: String?, emailId: String?,
                phoneNumber: String?, profileImageUrl: String? = nil, loginType: LoginType) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.emailId = emailId
        self.phoneNumber = phoneNumber
        self.imageUrl = profileImageUrl
        self.loginType = loginType
    }

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case emailId = "email_id"
        case phoneNumber = "phone_number"
        case imageUrl = "image_url"
        case loginType = "login_type"
    }
}

public enum LoginType: String, Codable {
    case Apple = "apple"
    case Google = "google"
    case Phone = "phone"
}
