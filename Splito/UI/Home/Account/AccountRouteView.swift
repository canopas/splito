//
//  AccountRouteView.swift
//  Splito
//
//  Created by Amisha Italiya on 27/02/24.
//

import Data
import SwiftUI
import BaseStyle

struct AccountRouteView: View {

    @StateObject var appRoute = Router(root: AppRoute.AccountHomeView)

    @Binding var isTabBarVisible: Bool

    var body: some View {
        RouterView(router: appRoute) { route in
            switch route {
            case .AccountHomeView:
                AccountHomeView(viewModel: AccountHomeViewModel(router: appRoute))
                    .onAppear { isTabBarVisible = true }
            case .ProfileView:
                UserProfileView(viewModel: UserProfileViewModel(router: appRoute, isOpenFromOnboard: false, onDismiss: nil))
                    .onAppear { isTabBarVisible = false }
            default:
                EmptyRouteView(routeName: self)
            }
        }
    }
}
