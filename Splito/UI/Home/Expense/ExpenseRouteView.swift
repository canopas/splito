//
//  ExpenseRouteView.swift
//  Splito
//
//  Created by Amisha Italiya on 26/03/24.
//

import Data
import SwiftUI
import BaseStyle
import UIPilot

struct ExpenseRouteView: View {

    @StateObject var appRoute = UIPilot(initial: AppRoute.AddExpenseView(expenseId: nil))

    let onDismiss: (() -> Void)?

    var body: some View {
        UIPilotHost(appRoute) { route in
            switch route {
            case .AddExpenseView:
                AddExpenseView(viewModel: AddExpenseViewModel(router: appRoute, onDismiss: onDismiss))
            default:
                EmptyRouteView(routeName: self)
            }
        }
    }
}
