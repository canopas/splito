//
//  MainRouteView.swift
//  Splito
//
//  Created by Amisha Italiya on 16/02/24.
//

import Data
import BaseStyle
import SwiftUI

public struct MainRouteView: View {

    @Inject var router: Router<MainRoute>
    @Inject var preference: SplitoPreference

    init() {
        Font.loadFonts()
    }

    public var body: some View {
        RouterView(router: router) { route in
            switch route {
            case .Onboard:
                OnboardView(viewModel: OnboardViewModel())
            case .Login:
                LoginView(viewModel: LoginViewModel())
            case .PhoneLogin:
                PhoneLoginView(viewModel: PhoneLoginViewModel())
            case .VerifyOTP(let phoneNumber, let verificationId):
                VerifyOtpView(viewModel: VerifyOtpViewModel(phoneNumber: phoneNumber, verificationId: verificationId))
            case .HomeRoute:
                HomeRouteView()
            }
        }
        .onAppear {
            if preference.isOnboardShown {
                if preference.isVerifiedUser {
                    router.updateRoot(root: .HomeRoute)
                } else {
                    router.updateRoot(root: .Login)
                }
            }
        }
    }
}
