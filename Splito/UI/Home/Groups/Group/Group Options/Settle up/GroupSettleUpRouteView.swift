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

    var body: some View {
        RouterView(router: appRoute) { route in
            switch route {
            case .GroupSettleUpView(let groupId):
                GroupSettleUpView(viewModel: GroupSettleUpViewModel(router: appRoute, groupId: groupId))
            case .GroupWhoIsPayingView(let groupId):
                GroupWhoIsPayingView(viewModel: GroupWhoIsPayingViewModel(router: appRoute, groupId: groupId))
            case .GroupWhoGettingPaidView(let groupId, let selectedMemberId):
                GroupWhoGettingPaidView(viewModel: GroupWhoGettingPaidViewModel(router: appRoute, groupId: groupId, selectedMemberId: selectedMemberId))
            case .GroupPaymentView(let groupId):
                GroupPaymentView(viewModel: GroupPaymentViewModel(router: appRoute, groupId: groupId))

            default:
                EmptyRouteView(routeName: self)
            }
        }
    }
}
