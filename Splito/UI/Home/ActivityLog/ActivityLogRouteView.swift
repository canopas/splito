//
//  ActivityLogRouteView.swift
//  Splito
//
//  Created by Amisha Italiya on 14/10/24.
//

import Data
import SwiftUI
import BaseStyle

struct ActivityLogRouteView: View {

    @StateObject var appRoute = Router(root: AppRoute.ActivityHomeView)

    @Binding var isTabBarVisible: Bool

    var body: some View {
        RouterView(router: appRoute) { route in
            switch route {
            case .ActivityHomeView:
                ActivityLogView(viewModel: ActivityLogViewModel(router: appRoute))
                    .onAppear { isTabBarVisible = true }
            case .GroupHomeView(let id):
                GroupHomeView(viewModel: GroupHomeViewModel(router: appRoute, groupId: id))
                    .onAppear { isTabBarVisible = false }
            case .GroupSettingView(let id):
                GroupSettingView(viewModel: GroupSettingViewModel(router: appRoute, groupId: id))
                    .onAppear { isTabBarVisible = false }
            case .ExpenseDetailView(let groupId, let expenseId):
                ExpenseDetailsView(viewModel: ExpenseDetailsViewModel(router: appRoute, groupId: groupId, expenseId: expenseId))
                    .onAppear { isTabBarVisible = false }
            case .TransactionDetailView(let transactionId, let groupId):
                GroupTransactionDetailView(viewModel: GroupTransactionDetailViewModel(router: appRoute, groupId: groupId, transactionId: transactionId))
                    .onAppear { isTabBarVisible = false }
            default:
                EmptyRouteView(routeName: self)
            }
        }
    }
}
