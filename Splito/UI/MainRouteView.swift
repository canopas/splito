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
            case .OnboardView:
                OnboardRouteView()
            case .HomeView:
                HomeRouteView()
            }
        }
        .onAppear {
            if preference.isVerifiedUser {
                router.updateRoot(root: .HomeView)
            }
        }
    }
}
