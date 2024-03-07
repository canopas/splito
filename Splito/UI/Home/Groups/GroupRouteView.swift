//
//  GroupRouteView.swift
//  Splito
//
//  Created by Amisha Italiya on 27/02/24.
//

import Data
import SwiftUI
import BaseStyle

struct GroupRouteView: View {

    @StateObject var appRoute = Router(root: AppRoute.GroupHome)

    var body: some View {
        VStack(spacing: 0) {
            RouterView(router: appRoute) { route in
                switch route {
                case .GroupHome:
                    GroupHomeView(viewModel: GroupHomeViewModel(router: appRoute))
                case .CreateGroup:
                    CreateGroupView(viewModel: CreateGroupViewModel())
                default:
                    EmptyRouteView(routeName: self)
                }
            }
        }
    }
}
