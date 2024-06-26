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

    var dismissPaymentFlow: () -> Void

    init(appRoute: Router<AppRoute>, dismissPaymentFlow: @escaping () -> Void) {
        self._appRoute = StateObject(wrappedValue: appRoute)
        self.dismissPaymentFlow = dismissPaymentFlow
    }

    var body: some View {
        RouterView(router: appRoute) { route in
            switch route {
            case .GroupSettleUpView(let groupId):
                GroupSettleUpView(viewModel: GroupSettleUpViewModel(router: appRoute, groupId: groupId))

            case .GroupWhoIsPayingView(let groupId, let isPaymentSettled):
                GroupWhoIsPayingView(viewModel: GroupWhoIsPayingViewModel(router: appRoute, groupId: groupId, isPaymentSettled: isPaymentSettled))

            case .GroupWhoGettingPaidView(let groupId, let selectedMemberId):
                GroupWhoGettingPaidView(viewModel: GroupWhoGettingPaidViewModel(router: appRoute,
                                                                                groupId: groupId, selectedMemberId: selectedMemberId))

            case .GroupPaymentView(let transactionId, let groupId, let payerId, let receiverId, let amount):
                GroupPaymentView(viewModel: GroupPaymentViewModel(router: appRoute, transactionId: transactionId, groupId: groupId,
                                                                  payerId: payerId, receiverId: receiverId,
                                                                  amount: amount, dismissPaymentFlow: dismissPaymentFlow))
            default:
                EmptyRouteView(routeName: self)
            }
        }
    }
}
