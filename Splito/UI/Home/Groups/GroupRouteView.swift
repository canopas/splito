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

    @StateObject var appRoute = Router(root: AppRoute.GroupListView)

    var body: some View {
        VStack(spacing: 0) {
            RouterView(router: appRoute) { route in
                switch route {
                case .GroupListView:
                    GroupListView(viewModel: GroupListViewModel(router: appRoute))
                case .GroupHomeView(let id):
                    GroupHomeView(viewModel: GroupHomeViewModel(router: appRoute, groupId: id))
                case .CreateGroupView:
                    CreateGroupView(viewModel: CreateGroupViewModel(router: appRoute))
                case .InviteMemberView(let id):
                    InviteMemberView(viewModel: InviteMemberViewModel(router: appRoute, groupId: id))
                case .JoinMemberView:
                    JoinMemberView(viewModel: JoinMemberViewModel(router: appRoute))
                default:
                    EmptyRouteView(routeName: self)
                }
            }
        }
    }
}
