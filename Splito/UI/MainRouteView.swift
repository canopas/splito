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

    @Inject var preference: SplitoPreference

    @StateObject var router = Router(root: AppRoute.OnboardView)

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
            default:
                EmptyRouteView(routeName: self)
            }
        }
        .onAppear {
            if preference.isVerifiedUser, let userName = preference.user?.firstName, !userName.isEmpty {
                router.updateRoot(root: .HomeView)
            }
        }
    }
}
