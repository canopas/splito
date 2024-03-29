//
//  AddExpenseViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 20/03/24.
//

import Combine
import Data

class AddExpenseViewModel: BaseViewModel, ObservableObject {

    @Inject var preference: SplitoPreference

    @Published var expenseName = ""
    @Published var expenseAmount = ""
    @Published var expenseDate = Date()

    @Published var payerName = "You"
    @Published var selectedGroup: Groups?

    @Published var selectedPayer: AppUser? {
        didSet {
            updatePayerName()
        }
    }

    @Published var showGroupSelection = false
    @Published var showPayerSelection = false

    @Published var openForGroupSelection = false

    private let router: Router<AppRoute>

    init(router: Router<AppRoute>) {
        self.router = router
        super.init()

        updatePayerName()
    }

    func updatePayerName() {
        if let user = preference.user, let selectedPayer, selectedPayer.id == user.id {
            self.payerName = "You"
        } else {
            self.payerName = selectedPayer?.firstName ?? "Unknown"
        }
    }

    // AddExpenseView Actions
    func saveExpense() {

    }
}
