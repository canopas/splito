//
//  LogInRouteView.swift
//  Splito
//
//  Created by Amisha Italiya on 16/02/24.
//

import Foundation
import SwiftUI
import BaseStyle

enum LoginRoute: Equatable, Hashable {

    public static func == (lhs: LoginRoute, rhs: LoginRoute) -> Bool {
        return lhs.key == rhs.key
    }

    case LoginView
    case PhoneLoginView
    case VerifyOTPView(phoneNumber: String, verificationId: String)

    public var key: String {
        switch self {
        case .LoginView:
            return "loginView"
        case .PhoneLoginView:
            return "phoneLoginView"
        case .VerifyOTPView:
            return "verifyOTPView"
        }
    }
}

// public struct LogInRouteView: View {
//
//    var router = Router<LoginRoute>(root: .LoginView)1111
//
//    public var body: some View {
//        RouterView(router: router) { route in
//            switch route {
//            case .LoginView:
//                LoginView(viewModel: LoginViewModel(router: router))
//            case .PhoneLoginView:
//                PhoneLoginView(viewModel: PhoneLoginViewModel(router: router))
//            case .VerifyOTPView(let phoneNumber, let verificationId):
//                VerifyOtpView(viewModel: VerifyOtpViewModel(router: router, phoneNumber: phoneNumber, verificationId: verificationId))
//            }
//        }
//    }
// }
