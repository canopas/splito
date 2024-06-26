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
    @Inject private var userRepository: UserRepository
    @Inject private var groupRepository: GroupRepository
    @Inject private var expenseRepository: ExpenseRepository

    @Published var expenseId: String?
    @Published var expenseName = ""
    @Published var expenseAmount = 0.0
    @Published var expenseDate = Date()

    @Published var groupMembers: [String] = []
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

    private let router: Router<AppRoute>

    init(router: Router<AppRoute>, expenseId: String? = nil, groupId: String? = nil) {
        self.router = router
        self.expenseId = expenseId

        super.init()

        if let expenseId {
            fetchExpenseDetails(expenseId: expenseId)
        } else if let groupId {
            fetchGroup(groupId: groupId)
            fetchDefaultUser()
        }
    }

    private func fetchGroup(groupId: String) {
        viewState = .loading
        groupRepository.fetchGroupBy(id: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServerError(error)
                }
            } receiveValue: { [weak self] group in
                guard let self, let group else { return }
                self.selectedGroup = group
                self.groupMembers = group.members
                self.selectedMembers = group.members
                self.viewState = .initial
            }.store(in: &cancelable)
    }

    private func fetchDefaultUser() {
        guard let id = preference.user?.id else { return }
        viewState = .loading

        userRepository.fetchUserBy(userID: id)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServerError(error)
                }
            } receiveValue: { [weak self] user in
                guard let self, let user else { return }
                self.selectedPayer = user
                self.viewState = .initial
            }.store(in: &cancelable)
    }

    private func updatePayerName() {
        if let user = preference.user, let selectedPayer, selectedPayer.id == user.id {
            self.payerName = "You"
        } else {
            self.payerName = selectedPayer?.nameWithLastInitial ?? "You"
        }
    }

    private func fetchExpenseDetails(expenseId: String) {
        viewState = .loading
        expenseRepository.fetchExpenseBy(expenseId: expenseId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServerError(error)
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
                    self.groupMembers = group?.members ?? []
                    self.fetchUserData(for: expense.paidBy) { user in
                        self.selectedPayer = user
                        self.viewState = .initial
                    }
                }
            }.store(in: &cancelable)
    }

    private func fetchGroupData(for groupId: String, completion: @escaping (Groups?) -> Void) {
        groupRepository.fetchGroupBy(id: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServerError(error)
                }
            } receiveValue: { group in
                completion(group)
            }.store(in: &cancelable)
    }

    private func fetchUserData(for userId: String, completion: @escaping (AppUser) -> Void) {
        groupRepository.fetchMemberBy(userId: userId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServerError(error)
                }
            } receiveValue: { user in
                guard let user else { return }
                completion(user)
            }.store(in: &cancelable)
    }

    private func handleServerError(_ error: ServiceError) {
        viewState = .initial
        showToastFor(error)
    }
}

// MARK: - User Actions

extension AddExpenseViewModel {

    func handleGroupBtnAction() {
        showGroupSelection = expenseId == nil
    }

    func handleGroupSelection(group: Groups) {
        selectedPayer = nil
        selectedGroup = group
        groupMembers = group.members
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
        if let user = preference.user, selectedPayer == nil {
            selectedPayer = user
        }

        if expenseName == "" || expenseAmount == 0 || selectedGroup == nil || selectedPayer == nil {
            showToastFor(toast: ToastPrompt(type: .warning, title: "Warning", message: "Please fill all data to add expense."))
            return
        }

        guard let selectedGroup, let selectedPayer, let groupId = selectedGroup.id, let user = preference.user else { return }

        if let expense {
            var newExpense = expense
            newExpense.name = expenseName.trimming(spaces: .leadingAndTrailing).capitalized
            newExpense.amount = expenseAmount
            newExpense.date = Timestamp(date: expenseDate)
            newExpense.paidBy = selectedPayer.id
            newExpense.splitTo = selectedMembers

            updateExpense(expense: newExpense)
        } else {
            let expense = Expense(name: expenseName.trimming(spaces: .leadingAndTrailing).capitalized, amount: expenseAmount,
                                  date: Timestamp(date: expenseDate), paidBy: selectedPayer.id,
                                  addedBy: user.id, splitTo: selectedMembers, groupId: groupId)

            addExpense(expense: expense, completion: completion)
        }
    }

    private func addExpense(expense: Expense, completion: @escaping () -> Void) {
        viewState = .loading
        expenseRepository.addExpense(expense: expense)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServerError(error)
                }
            } receiveValue: { [weak self] _ in
                self?.viewState = .initial
                completion()
            }.store(in: &cancelable)
    }

    private func updateExpense(expense: Expense) {
        viewState = .loading
        expenseRepository.updateExpense(expense: expense)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServerError(error)
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
