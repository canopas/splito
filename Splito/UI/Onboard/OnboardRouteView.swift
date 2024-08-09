//
//  OnboardRouteView.swift
//  Splito
//
//  Created by Amisha Italiya on 14/03/24.
//

import Data
import SwiftUI
import BaseStyle

struct OnboardRouteView: View {

    @StateObject var router = Router(root: AppRoute.OnboardView)

    @Inject var preference: SplitoPreference

    var body: some View {
        RouterView(router: router) { route in
            switch route {
            case .OnboardView:
                OnboardView(viewModel: OnboardViewModel(router: router))
            case .LoginView:
                LoginView(viewModel: LoginViewModel(router: router))
            case .PhoneLoginView:
                PhoneLoginView(viewModel: PhoneLoginViewModel(router: router))
            case .VerifyOTPView(let phoneNumber, let dialCode, let verificationId):
                VerifyOtpView(viewModel: VerifyOtpViewModel(router: router, phoneNumber: phoneNumber, dialCode: dialCode, verificationId: verificationId))
            default:
                EmptyRouteView(routeName: self)
            }
        }
        .onAppear {
            if preference.isOnboardShown, !preference.isVerifiedUser {
                router.updateRoot(root: .LoginView)
            }
        }
    }
}
