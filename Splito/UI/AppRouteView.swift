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

    var router = Router<AppRoute>(root: .OnboardView)

    @Inject var preference: SplitoPreference

    init() {
        Font.loadFonts()
    }

    public var body: some View {
        RouterView(router: router) { route in
            switch route {
            case .OnboardView:
                OnboardView(viewModel: OnboardViewModel(appRouter: router))
            case .LoginView:
                LoginView(viewModel: LoginViewModel(router: router))
            case .PhoneLoginView:
                PhoneLoginView(viewModel: PhoneLoginViewModel(router: router))
            case .VerifyOTPView(let phoneNumber, let verificationId):
                VerifyOtpView(viewModel: VerifyOtpViewModel(router: router, phoneNumber: phoneNumber, verificationId: verificationId))
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
