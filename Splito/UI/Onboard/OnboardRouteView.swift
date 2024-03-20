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
            case .VerifyOTPView(let phoneNumber, let verificationId):
                VerifyOtpView(viewModel: VerifyOtpViewModel(router: router, phoneNumber: phoneNumber, verificationId: verificationId))
            case .ProfileView:
                UserProfileView(viewModel: UserProfileViewModel(router: router, isOpenedFromOnboard: true))
            case .HomeView:
                HomeRouteView()
            default:
                EmptyRouteView(routeName: self)
            }
        }
        .onAppear {
            if preference.isOnboardShown {
                if preference.isVerifiedUser {
                    router.updateRoot(root: .ProfileView)
                } else {
                    router.updateRoot(root: .LoginView)
                }
            } else {
                router.updateRoot(root: .OnboardView)
            }
        }
    }
}
