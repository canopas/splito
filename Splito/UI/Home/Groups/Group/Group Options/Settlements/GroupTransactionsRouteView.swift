//
//  GroupTransactionsRouteView.swift
//  Splito
//
//  Created by Amisha Italiya on 20/06/24.
//

import BaseStyle
import Data
import SwiftUI

struct GroupTransactionsRouteView: View {

    @StateObject var appRoute: Router<AppRoute>

    init(appRoute: Router<AppRoute>) {
        self._appRoute = StateObject(wrappedValue: appRoute)
    }

    var body: some View {
        RouterView(router: appRoute) { route in
            switch route {
            case .TransactionListView(let groupId):
                GroupTransactionListView(viewModel: GroupTransactionListViewModel(router: appRoute, groupId: groupId))
            case .TransactionDetailView(let transactionId, let groupId):
                GroupTransactionDetailView(viewModel: GroupTransactionDetailViewModel(router: appRoute, groupId: groupId, transactionId: transactionId))
            case .GroupPaymentView(let transactionId, let groupId, let payerId, let receiverId, let amount):
                GroupPaymentView(
                    viewModel: GroupPaymentViewModel(
                        router: appRoute, transactionId: transactionId, groupId: groupId,
                        payerId: payerId, receiverId: receiverId, amount: amount
                    )
                )
            default:
                EmptyRouteView(routeName: self)
            }
        }
    }
}
