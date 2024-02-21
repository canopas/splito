//
//  AppRouteView.swift
//  Splito
//
//  Created by Amisha Italiya on 16/02/24.
//

import Data
import SwiftUI

public enum AppRootRoute: Equatable {
    case Onboard
    case Login
    case Home
}

public struct AppRouteView: View {

    var router = Router<AppRootRoute>(root: .Onboard)

    @Inject var preference: SplitoPreference

    public var body: some View {
        RouterView(router: router) { route in
            switch route {
            case .Onboard:
                OnboardView(viewModel: OnboardViewModel(appRouter: router))
            case .Login:
                LogInRouteView()
            case .Home:
                HomeView()
            }
        }
        .onAppear {
            if preference.isOnboardShown {
                if preference.isLoggedIn {
                    router.updateRoot(root: .Home)
                } else {
                    router.updateRoot(root: .Login)
                }
            }
        }
    }
}
