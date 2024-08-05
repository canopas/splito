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

    var dismissPaymentFlow: () -> Void

    init(appRoute: Router<AppRoute>, dismissPaymentFlow: @escaping () -> Void) {
        self._appRoute = StateObject(wrappedValue: appRoute)
        self.dismissPaymentFlow = dismissPaymentFlow
    }

    var body: some View {
        RouterView(router: appRoute) { route in
            switch route {
            case .TransactionListView(let groupId):
                GroupTransactionListView(viewModel: GroupTransactionListViewModel(router: appRoute, groupId: groupId))

            case .TransactionDetailView(let transactionId, let groupId):
                GroupTransactionDetailView(
                    viewModel: GroupTransactionDetailViewModel(
                        router: appRoute, groupId: groupId, transactionId: transactionId
                    )
                )
            case .GroupPaymentView(let transactionId, let groupId, let payerId, let receiverId, let amount):
                GroupPaymentView(
                    viewModel: GroupPaymentViewModel(
                        router: appRoute, transactionId: transactionId,
                        groupId: groupId, payerId: payerId, receiverId: receiverId,
                        amount: amount, dismissPaymentFlow: dismissPaymentFlow
                    )
                )
            default:
                EmptyRouteView(routeName: self)
            }
        }
    }
}
