//
//  AppRoute.swift
//  Data
//
//  Created by Amisha Italiya on 26/02/24.
//

import Foundation

public enum AppRoute: Equatable, Hashable {
    case OnboardView
    case LoginView
    case PhoneLoginView
    case VerifyOTPView(phoneNumber: String, verificationId: String)
    case Home
}
