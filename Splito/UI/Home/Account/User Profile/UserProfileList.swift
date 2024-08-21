//
//  UserProfileList.swift
//  Splito
//
//  Created by Amisha Italiya on 14/03/24.
//

import UIKit
import SwiftUI

enum UserProfileList: Int, CaseIterable {

    var id: String {
        return String(describing: self)
    }

    case firstName
    case lastName
    case phone
    case email

    var subtitle: String {
        switch self {
        case .firstName:
            return "First Name"
        case .lastName:
            return "Last Name"
        case .phone:
            return "Phone Number"
        case .email:
            return "Email"
        }
    }

    var placeholder: String {
        switch self {
        case .firstName:
            return "Enter your first name"
        case .lastName:
            return "Enter your last name"
        case .phone:
            return "Enter your phone number"
        case .email:
            return "Enter your email address"
        }
    }

    var keyboardType: UIKeyboardType {
        switch self {
        case .phone:
            return .phonePad
        case .email:
            return .emailAddress
        default:
            return .default
        }
    }

    var isDisabled: Bool {
        switch self {
        case .phone:
            return true
        default:
            return false
        }
    }

    var validationType: TextFieldValidationType {
        switch self {
        case .firstName:
            return .firstName
        case .phone:
            return .phone
        case .email:
            return .email
        default:
            return .nonEmpty
        }
    }

    var fieldTypes: UserProfileList {
        switch self {
        case .firstName:
            return .firstName
        case .lastName:
            return .lastName
        case .phone:
            return .phone
        case .email:
            return .email
        }
    }

    var autoCapitalizationType: TextInputAutocapitalization {
        switch self {
        case .firstName:
            return .words
        case .lastName:
            return .words
        case .phone:
            return .never
        case .email:
            return .never
        }
    }
}

enum TextFieldValidationType {
    case firstName
    case phone
    case email
    case nonEmpty
    case none

    var errorText: String {
        switch self {
        case .firstName:
            return "Minimum 3 characters are required"
        case .phone:
            return "Please enter valid phone number"
        case .email:
            return "Please enter valid email"
        default:
            return ""
        }
    }
}
