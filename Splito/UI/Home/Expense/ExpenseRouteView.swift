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

    var groupId: String?

    @StateObject var appRoute: Router<AppRoute>

    init(groupId: String? = nil) {
        self.groupId = groupId
        _appRoute = StateObject(wrappedValue: Router(root: AppRoute.AddExpenseView(expenseId: nil, groupId: groupId)))
        print("xxx \(groupId)")
    }

    var body: some View {
        RouterView(router: appRoute) { route in
            switch route {
            case .AddExpenseView(let expenseId, let groupId):
                AddExpenseView(viewModel: AddExpenseViewModel(router: appRoute, expenseId: expenseId, groupId: groupId))
                    .background()
            default:
                EmptyRouteView(routeName: self)
            }
        }
    }
}
