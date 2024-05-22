//
//  MainRouteView.swift
//  Splito
//
//  Created by Amisha Italiya on 16/02/24.
//

import Data
import BaseStyle
import SwiftUI
import UIPilot

public struct MainRouteView: View {

    @Inject var router: UIPilot<MainRoute>
    @Inject var preference: SplitoPreference

    init() {
        Font.loadFonts()
    }

    public var body: some View {
        UIPilotHost(router) { route in
            switch route {
            case .OnboardView:
                OnboardRouteView()
            case .HomeView:
                HomeRouteView()
            }
        }
        .onAppear {
            if preference.isVerifiedUser {
                router.popTo(.OnboardView, inclusive: true)
                router.push(.HomeView)
            }
        }
    }
}
