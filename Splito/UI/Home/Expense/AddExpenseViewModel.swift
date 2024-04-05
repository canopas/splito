//
//  AddExpenseViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 20/03/24.
//

import Data
import Combine
import BaseStyle
import FirebaseFirestoreInternal

class AddExpenseViewModel: BaseViewModel, ObservableObject {

    @Inject var preference: SplitoPreference
    @Inject var expenseRepository: ExpenseRepository

    @Published var expenseName = ""
    @Published var expenseAmount = 0.0
    @Published var expenseDate = Date()

    @Published var showGroupSelection = false
    @Published var showPayerSelection = false
    @Published var currentViewState: ViewState = .initial

    @Published var payerName = "You"
    @Published var selectedGroup: Groups?

    @Published var selectedPayer: AppUser? {
        didSet {
            updatePayerName()
        }
    }

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

    func saveExpense(completion: @escaping () -> Void) {

        if expenseName == "" || expenseAmount == 0 || selectedGroup == nil || selectedPayer == nil {
            showToastFor(toast: ToastPrompt(type: .warning, title: "Warning", message: "Please fill all data to add expense."))
            return
        }

        guard let selectedGroup, let selectedPayer, let groupId = selectedGroup.id else { return }

        currentViewState = .loading
        let expense = Expense(name: expenseName, amount: expenseAmount, date: Timestamp(date: expenseDate),
                              paidBy: selectedPayer.id, splitTo: selectedGroup.members, groupId: groupId)

        expenseRepository.addExpense(expense: expense)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] _ in
                self?.currentViewState = .initial
                completion()
            }.store(in: &cancelable)
    }
}

extension AddExpenseViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
