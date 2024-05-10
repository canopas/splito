//
//  UserProfileList.swift
//  Splito
//
//  Created by Amisha Italiya on 14/03/24.
//

import UIKit

enum UserProfileList: Int, CaseIterable {

    var id: String {
        return String(describing: self)
    }

    case firstName
    case lastName
    case email
    case phone

    var subtitle: String {
        switch self {
        case .firstName:
            return "First name"
        case .lastName:
            return "Last name"
        case .email:
            return "Email"
        case .phone:
            return "Phone number"
        }
    }

    var placeholder: String {
        switch self {
        case .firstName:
            return "Enter first name"
        case .lastName:
            return "Enter last name"
        case .email:
            return "Enter last"
        case .phone:
            return "Enter phone number"
        }
    }

    var keyboardType: UIKeyboardType {
        switch self {
        case .email:
            return .emailAddress
        case .phone:
            return .phonePad
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
        case .email:
            return .email
        case .phone:
            return .phone
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
        case .email:
            return .email
        case .phone:
            return .phone
        }
    }

    var autoCapitalizationType: UITextAutocapitalizationType {
        switch self {
        case .firstName:
            return .words
        case .lastName:
            return .words
        case .email:
            return .none
        case .phone:
            return .none
        }
    }
}

enum TextFieldValidationType {
    case firstName
    case email
    case phone
    case nonEmpty
    case none

    var errorText: String {
        switch self {
        case .firstName:
            return "Minimum 3 characters are required"
        case .email:
            return "Please enter valid email"
        case .phone:
            return "Please enter valid phone number"
        default:
            return ""
        }
    }
}
