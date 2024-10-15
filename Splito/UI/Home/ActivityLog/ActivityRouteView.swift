//
//  ActivityRouteView.swift
//  Splito
//
//  Created by Nirali Sonani on 14/10/24.
//

import Data
import SwiftUI
import BaseStyle

struct ActivityRouteView: View {

    @StateObject var appRoute = Router(root: AppRoute.ActivityHomeView)

    @Binding var isTabBarVisible: Bool

    var body: some View {
        RouterView(router: appRoute) { route in
            switch route {
            case .ActivityHomeView:
                ActivityView(viewModel: ActivityViewModel(router: appRoute))
                    .onAppear { isTabBarVisible = true }
            case .GroupHomeView(let id):
                GroupHomeView(viewModel: GroupHomeViewModel(router: appRoute, groupId: id))
                    .onAppear { isTabBarVisible = false }
            case .ExpenseDetailView(let groupId, let expenseId):
                ExpenseDetailsView(viewModel: ExpenseDetailsViewModel(router: appRoute, groupId: groupId, expenseId: expenseId))
            case .TransactionDetailView(let transactionId, let groupId):
                GroupTransactionDetailView(viewModel: GroupTransactionDetailViewModel(router: appRoute, groupId: groupId, transactionId: transactionId))
            default:
                EmptyRouteView(routeName: self)
            }
        }
    }
}
