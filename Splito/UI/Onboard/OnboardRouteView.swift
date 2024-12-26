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
    @State var tint: Color = primaryText

    @Inject var preference: SplitoPreference

    var onDismiss: (() -> Void)?

    var body: some View {
        RouterView(router: router, tint: tint) { route in
            switch route {
            case .OnboardView:
                OnboardView(viewModel: OnboardViewModel(router: router))
            case .LoginView:
                LoginView(viewModel: LoginViewModel(router: router, onDismiss: onDismiss))
            case .EmailLoginView(let onDismiss):
                EmailLoginView(viewModel: EmailLoginViewModel(router: router, onDismiss: onDismiss))
                    .onAppear {
                        tint = primaryDarkText
                    }
            default:
                EmptyRouteView(routeName: self)
            }
        }
        .onAppear {
            if preference.isOnboardShown && (!preference.isVerifiedUser || preference.user == nil) {
                router.updateRoot(root: .LoginView)
            }
        }
    }
}
