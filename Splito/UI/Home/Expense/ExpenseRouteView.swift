//
//  ExpenseRouteView.swift
//  Splito
//
//  Created by Amisha Italiya on 26/03/24.
//

import Data
import SwiftUI
import BaseStyle

struct ExpenseRouteView: View {

    @StateObject var appRoute = Router(root: AppRoute.AddExpenseView(groupId: "", expenseId: nil))

    var body: some View {
        RouterView(router: appRoute) { route in
            switch route {
            case .AddExpenseView(let groupId, let expenseId):
                AddExpenseView(viewModel: AddExpenseViewModel(router: appRoute, groupId: groupId, expenseId: expenseId))
            default:
                EmptyRouteView(routeName: self)
            }
        }
    }
}
