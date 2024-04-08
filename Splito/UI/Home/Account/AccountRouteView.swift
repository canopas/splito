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

    var body: some View {
        RouterView(router: appRoute) { route in
            switch route {
            case .AccountHomeView:
                AccountHomeView(viewModel: AccountHomeViewModel(router: appRoute))
            case .ProfileView:
                UserProfileView(viewModel: UserProfileViewModel(router: appRoute, isOpenedFromOnboard: false))
            default:
                EmptyRouteView(routeName: self)
            }
        }
    }
}
