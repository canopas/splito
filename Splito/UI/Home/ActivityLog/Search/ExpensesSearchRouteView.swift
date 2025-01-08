//
//  ExpensesSearchRouteView.swift
//  Splito
//
//  Created by Amisha Italiya on 06/01/25.
//

import Data
import SwiftUI
import BaseStyle

struct ExpensesSearchRouteView: View {

    @StateObject var appRoute: Router<AppRoute>

    init(appRoute: Router<AppRoute>) {
        self._appRoute = StateObject(wrappedValue: appRoute)
    }

    var body: some View {
        RouterView(router: appRoute) { route in
            switch route {
            case .ExpensesSearchView:
                ExpensesSearchView(viewModel: ExpensesSearchViewModel(router: appRoute))
            case .ExpenseDetailView(let groupId, let expenseId):
                ExpenseDetailsView(viewModel: ExpenseDetailsViewModel(router: appRoute, groupId: groupId, expenseId: expenseId))
            default:
                EmptyRouteView(routeName: self)
            }
        }
    }
}
