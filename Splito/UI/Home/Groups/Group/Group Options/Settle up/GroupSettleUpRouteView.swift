//
//  GroupSettleUpRouteView.swift
//  Splito
//
//  Created by Amisha Italiya on 04/06/24.
//

import Data
import SwiftUI
import BaseStyle

struct GroupSettleUpRouteView: View {

    @StateObject var appRoute: Router<AppRoute>

    init(appRoute: Router<AppRoute>) {
        self._appRoute = StateObject(wrappedValue: appRoute)
    }

    var body: some View {
        RouterView(router: appRoute) { route in
            switch route {
            case .GroupSettleUpView(let groupId):
                GroupSettleUpView(viewModel: GroupSettleUpViewModel(router: appRoute, groupId: groupId))

            case .GroupWhoIsPayingView(let groupId, let isPaymentSettled):
                GroupWhoIsPayingView(viewModel: GroupWhoIsPayingViewModel(router: appRoute, groupId: groupId, isPaymentSettled: isPaymentSettled))

            case .GroupWhoGettingPaidView(let groupId, let payerId):
                GroupWhoGettingPaidView(viewModel: GroupWhoGettingPaidViewModel(router: appRoute, groupId: groupId, payerId: payerId))

            case .GroupPaymentView(let transactionId, let groupId, let payerId, let receiverId,
                                   let amount, let currency):
                GroupPaymentView(viewModel: GroupPaymentViewModel(router: appRoute, transactionId: transactionId,
                                                                  groupId: groupId, payerId: payerId,
                                                                  receiverId: receiverId, amount: amount,
                                                                  currency: currency))
            default:
                EmptyRouteView(routeName: self)
            }
        }
    }
}
