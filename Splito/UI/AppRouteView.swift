//
//  AppRouteView.swift
//  Splito
//
//  Created by Amisha Italiya on 16/02/24.
//

import Data
import BaseStyle
import SwiftUI

public struct AppRouteView: View {

    @Inject var router: Router<AppRoute>
    @Inject var preference: SplitoPreference

    init() {
        Font.loadFonts()
    }

    public var body: some View {
        RouterView(router: router) { route in
            switch route {
            case .OnboardView:
                OnboardView(viewModel: OnboardViewModel())
            case .LoginView:
                LoginView(viewModel: LoginViewModel())
            case .PhoneLoginView:
                PhoneLoginView(viewModel: PhoneLoginViewModel())
            case .VerifyOTPView(let phoneNumber, let verificationId):
                VerifyOtpView(viewModel: VerifyOtpViewModel(phoneNumber: phoneNumber, verificationId: verificationId))
            case .Home:
                HomeView()
            }
        }
        .onAppear {
            if preference.isOnboardShown {
                if preference.isVerifiedUser {
                    router.updateRoot(root: .Home)
                } else {
                    router.updateRoot(root: .LoginView)
                }
            }
        }
    }
}
