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
        RouterView(router: appRoute) { route in
            switch route {
            case .GroupListView:
                GroupListView(viewModel: GroupListViewModel(router: appRoute))
            case .GroupHomeView(let id):
                GroupHomeView(viewModel: GroupHomeViewModel(router: appRoute, groupId: id))
            case .CreateGroupView(let group):
                CreateGroupView(viewModel: CreateGroupViewModel(router: appRoute, group: group))
            case .InviteMemberView(let id):
                InviteMemberView(viewModel: InviteMemberViewModel(router: appRoute, groupId: id))
            case .JoinMemberView:
                JoinMemberView(viewModel: JoinMemberViewModel(router: appRoute))
            case .GroupSettingView(let id):
                GroupSettingView(viewModel: GroupSettingViewModel(router: appRoute, groupId: id))
            case .ExpenseDetailView(let groupId, let expenseId):
                ExpenseDetailsView(viewModel: ExpenseDetailsViewModel(router: appRoute, groupId: groupId, expenseId: expenseId))
            case .AddExpenseView(let groupId, let expenseId):
                AddExpenseView(viewModel: AddExpenseViewModel(router: appRoute, groupId: groupId, expenseId: expenseId))
            case .TransactionListView(let groupId):
                GroupTransactionListView(viewModel: GroupTransactionListViewModel(router: appRoute, groupId: groupId))
            case .TransactionDetailView(let transactionId, let groupId):
                GroupTransactionDetailView(viewModel: GroupTransactionDetailViewModel(router: appRoute, groupId: groupId, transactionId: transactionId))
            default:
                EmptyRouteView(routeName: self)
            }
        }
    }
}
