//
//  AddExpenseViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 20/03/24.
//

import Combine
import Data

class AddExpenseViewModel: BaseViewModel, ObservableObject {

    @Published var expenseName = ""
    @Published var expenseAmount = ""
    @Published var expenseDate = Date()

    @Published var paidByMember: Member?
    @Published var selectedGroup: Groups?

    @Published var showGroupSelection = false
    @Published var showMemberSelection = false

    @Published var openForGroupSelection = false

    private let router: Router<AppRoute>

    init(router: Router<AppRoute>) {
        self.router = router
    }

    // AddExpenseView Actions
    func saveExpense() {

    }

}
