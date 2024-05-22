//
//  OnboardRouteView.swift
//  Splito
//
//  Created by Amisha Italiya on 14/03/24.
//

import Data
import SwiftUI
import BaseStyle
import UIPilot

struct OnboardRouteView: View {

    @StateObject var router = UIPilot(initial: AppRoute.OnboardView)

    @Inject var preference: SplitoPreference

    var body: some View {
        UIPilotHost(router) { route in
            switch route {
            case .OnboardView:
                OnboardView(viewModel: OnboardViewModel(router: router))
            case .LoginView:
                LoginView(viewModel: LoginViewModel(router: router))
            case .PhoneLoginView:
                PhoneLoginView(viewModel: PhoneLoginViewModel(router: router))
            case .VerifyOTPView(let phoneNumber, let verificationId):
                VerifyOtpView(viewModel: VerifyOtpViewModel(router: router, phoneNumber: phoneNumber, verificationId: verificationId))
            default:
                EmptyRouteView(routeName: self)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if preference.isOnboardShown, !preference.isVerifiedUser {
                router.popTo(.OnboardView, inclusive: true)
                router.push(.LoginView)
            }
        }
    }
}
