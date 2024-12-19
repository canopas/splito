//
//  AppUser.swift
//  Data
//
//  Created by Amisha Italiya on 26/02/24.
//

import Foundation

public struct AppUser: Identifiable, Codable, Hashable, Sendable {

    public var id: String
    public var firstName: String?
    public var lastName: String?
    public var emailId: String?
    public var phoneNumber: String?
    public var imageUrl: String?
    public var deviceFcmToken: String?
    public var loginType: LoginType
    public var totalOweAmount: Double
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
                phoneNumber: String? = nil, imageUrl: String? = nil, deviceFcmToken: String? = nil,
                loginType: LoginType, totalOweAmount: Double = 0, isActive: Bool = true) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.emailId = emailId
        self.phoneNumber = phoneNumber
        self.imageUrl = imageUrl
        self.deviceFcmToken = deviceFcmToken
        self.loginType = loginType
        self.totalOweAmount = totalOweAmount
        self.isActive = isActive
    }

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case emailId = "email_id"
        case phoneNumber = "phone_number"
        case imageUrl = "image_url"
        case deviceFcmToken = "device_fcm_token"
        case loginType = "login_type"
        case totalOweAmount = "total_owe_amount"
        case isActive = "is_active"
    }
}

public enum LoginType: String, Codable, Sendable {
    case Apple = "apple"
    case Google = "google"
    case Email = "email"
}
