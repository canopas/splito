//
//  AppUser.swift
//  Data
//
//  Created by Amisha Italiya on 26/02/24.
//

import Foundation

public struct AppUser: Identifiable, Codable {

    public var id: String
    public var firstName: String?
    public var lastName: String?
    public var emailId: String?
    public var phoneNumber: String?
    public var imageUrl: String?
    public let loginType: LoginType
    public var isActive: Bool

    public var fullName: String {
        if let firstName, let lastName {
            return firstName + " " + lastName
        } else {
            return firstName ?? ""
        }
    }

    public var nameWithLastInitial: String {
        let firstName = firstName ?? ""
        let lastNameInitial = lastName?.first.map { String($0) } ?? ""
        return firstName + (lastNameInitial.isEmpty ? "" : " \(lastNameInitial).")
    }

    public init(id: String, firstName: String?, lastName: String?, emailId: String?,
                phoneNumber: String?, profileImageUrl: String? = nil, loginType: LoginType, isActive: Bool = true) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.emailId = emailId
        self.phoneNumber = phoneNumber
        self.imageUrl = profileImageUrl
        self.loginType = loginType
        self.isActive = isActive
    }

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case emailId = "email_id"
        case phoneNumber = "phone_number"
        case imageUrl = "image_url"
        case loginType = "login_type"
        case isActive = "is_active"
    }
}

public enum LoginType: String, Codable {
    case Apple = "apple"
    case Google = "google"
    case Phone = "phone"
}
