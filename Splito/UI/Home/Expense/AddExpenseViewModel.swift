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

    @Inject private var preference: SplitoPreference
    @Inject private var groupRepository: GroupRepository
    @Inject private var expenseRepository: ExpenseRepository

    @Published var expenseName = ""
    @Published var expenseAmount = 0.0
    @Published var expenseDate = Date()
    @Published var selectedMembers: [String] = []

    @Published var showGroupSelection = false
    @Published var showPayerSelection = false
    @Published var showSplitTypeSelection = false

    @Published var payerName = "You"
    @Published var expense: Expense?
    @Published var selectedGroup: Groups?
    @Published var viewState: ViewState = .initial

    @Published var selectedPayer: AppUser? {
        didSet {
            updatePayerName()
        }
    }

    let expenseId: String?
    private let router: Router<AppRoute>

    init(router: Router<AppRoute>, expenseId: String? = nil) {
        self.router = router
        self.expenseId = expenseId

        super.init()

        if let expenseId {
            fetchExpenseDetails(expenseId: expenseId)
        } else {
            updatePayerName()
        }
    }

    private func updatePayerName() {
        if let user = preference.user, let selectedPayer, selectedPayer.id == user.id {
            self.payerName = "You"
        } else {
            self.payerName = selectedPayer?.nameWithLastInitial ?? "Unknown"
        }
    }

    func fetchExpenseDetails(expenseId: String) {
        viewState = .loading
        expenseRepository.fetchExpenseBy(expenseId: expenseId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.viewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] expense in
                guard let self else { return }
                self.expense = expense
                self.expenseName = expense.name
                self.expenseAmount = expense.amount
                self.expenseDate = expense.date.dateValue()
                self.selectedMembers = expense.splitTo

                self.fetchGroupData(for: expense.groupId) { group in
                    self.selectedGroup = group
                    self.fetchUserData(for: expense.paidBy) { user in
                        self.selectedPayer = user
                        self.viewState = .initial
                    }
                }
            }.store(in: &cancelable)
    }

    func fetchGroupData(for groupId: String, completion: @escaping (Groups?) -> Void) {
        groupRepository.fetchGroupBy(id: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.viewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { group in
                completion(group)
            }.store(in: &cancelable)
    }

    func fetchUserData(for userId: String, completion: @escaping (AppUser) -> Void) {
        groupRepository.fetchMemberBy(userId: userId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.viewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { user in
                guard let user else { return }
                completion(user)
            }.store(in: &cancelable)
    }

    // MARK: - Actions
    func handleGroupBtnAction() {
        showGroupSelection = expenseId == nil
    }

    func handleGroupSelection(group: Groups) {
        selectedGroup = group
        selectedPayer = nil
        selectedMembers = group.members
    }

    func handlePayerBtnAction() {
        guard selectedGroup != nil else {
            self.showToastFor(toast: ToastPrompt(type: .warning, title: "Whoops!", message: "Please select group to get payer list."))
            return
        }
        showPayerSelection = true
    }

    func handlePayerSelection(payer: AppUser) {
        selectedPayer = payer
    }

    func handleSplitTypeBtnAction() {
        guard selectedGroup != nil else {
            self.showToastFor(toast: ToastPrompt(type: .warning, title: "Whoops!", message: "Please select group to get payer list."))
            return
        }

        guard expenseAmount > 0 else {
            self.showToastFor(toast: ToastPrompt(type: .warning, title: "Whoops!", message: "Please enter a cost for your expense first!"))
            return
        }
        showSplitTypeSelection = true
    }

    func handleSplitTypeSelection(members: [String]) {
        selectedMembers = members
    }

    func handleSaveAction(completion: @escaping () -> Void) {
        if expenseName == "" || expenseAmount == 0 || selectedGroup == nil || selectedPayer == nil {
            showToastFor(toast: ToastPrompt(type: .warning, title: "Warning", message: "Please fill all data to add expense."))
            return
        }

        guard let selectedGroup, let selectedPayer, let groupId = selectedGroup.id, let user = preference.user else { return }

        if let expense {
            var newExpense = expense
            newExpense.name = expenseName.capitalized
            newExpense.amount = expenseAmount
            newExpense.date = Timestamp(date: expenseDate)
            newExpense.paidBy = selectedPayer.id
            newExpense.splitTo = selectedMembers

            updateExpense(expense: newExpense)
        } else {
            let expense = Expense(name: expenseName.capitalized, amount: expenseAmount,
                                  date: Timestamp(date: expenseDate), paidBy: selectedPayer.id,
                                  addedBy: user.id, splitTo: selectedMembers, groupId: groupId)

            addExpense(expense: expense, completion: completion)
        }
    }

    func addExpense(expense: Expense, completion: @escaping () -> Void) {
        viewState = .loading
        expenseRepository.addExpense(expense: expense)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.viewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] _ in
                self?.viewState = .initial
                completion()
            }.store(in: &cancelable)
    }

    func updateExpense(expense: Expense) {
        viewState = .loading
        expenseRepository.updateExpense(expense: expense)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.viewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] _ in
                self?.viewState = .initial
                self?.router.pop()
            }.store(in: &cancelable)
    }
}

extension AddExpenseViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
