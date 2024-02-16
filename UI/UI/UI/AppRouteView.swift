//
//  AppRouteView.swift
//  UI
//
//  Created by Amisha Italiya on 16/02/24.
//

import Foundation
import SwiftUI
import Data

public enum AppRoute: Equatable {
    case Onboard
    case Login
    case Home
}

public struct AppRouteView: View {
    
    var router = Router<AppRoute>(root: .Onboard)
    
    @Inject var preference: SplitoPreference
    
    public init() {}
    
    public var body: some View {
        RouterView(router: router) { route in
            switch route {
            case .Onboard:
                OnboardView(viewModel: OnboardViewModel(appRouter: router))
            case .Login:
                LoginView()
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
