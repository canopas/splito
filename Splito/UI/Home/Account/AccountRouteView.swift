//
//  AccountRouteView.swift
//  Splito
//
//  Created by Amisha Italiya on 27/02/24.
//

import Data
import SwiftUI
import BaseStyle
import UIPilot

struct AccountRouteView: View {

    @StateObject var appRoute = UIPilot(initial: AppRoute.AccountHomeView)

    var body: some View {
        UIPilotHost(appRoute) { route in
            switch route {
            case .AccountHomeView:
                AccountHomeView(viewModel: AccountHomeViewModel(router: appRoute))
            case .ProfileView:
                UserProfileView(viewModel: UserProfileViewModel(router: appRoute, isOpenedFromOnboard: false, onDismiss: nil))
            default:
                EmptyRouteView(routeName: self)
            }
        }
    }
}
