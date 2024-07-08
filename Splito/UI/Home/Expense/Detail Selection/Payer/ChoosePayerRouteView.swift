//
//  ChoosePayerRouteView.swift
//  Splito
//
//  Created by Nirali Sonani on 08/07/24.
//

import Data
import SwiftUI
import BaseStyle

struct ChoosePayerRouteView: View {

    @StateObject var appRoute: Router<AppRoute>

    var dismissChoosePayerFlow: () -> Void

    init(appRoute: Router<AppRoute>, dismissChoosePayerFlow: @escaping () -> Void) {
        self._appRoute = StateObject(wrappedValue: appRoute)
        self.dismissChoosePayerFlow = dismissChoosePayerFlow
    }

    var body: some View {
        RouterView(router: appRoute) { route in
            switch route {
            case .ChoosePayerView(let groupId, let amount, let selectedPayer, let onPayerSelection):
                ChoosePayerView(viewModel: ChoosePayerViewModel(router: appRoute, groupId: groupId, amount: amount, selectedPayers: selectedPayer, onPayerSelection: onPayerSelection))

            case .ChooseMultiplePayerView(let groupId, let amount, let onPayerSelection):
                ChooseMultiplePeopleView(viewModel: ChooseMultiplePeopleViewModel(groupId: groupId, expenseAmount: amount, onPayerSelection: onPayerSelection, dismissChoosePayerFlow: dismissChoosePayerFlow))
            default:
                EmptyRouteView(routeName: self)
            }
        }
    }
}
