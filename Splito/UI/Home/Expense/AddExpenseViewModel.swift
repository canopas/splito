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

    @Published var expenseName = ""
    @Published private(set) var payerName = "You"
    @Published private(set) var expenseId: String?

    @Published var expenseAmount: Double = 0.00
    @Published var expenseDate = Date()

    @Published var showGroupSelection = false
    @Published var showPayerSelection = false
    @Published var showSplitTypeSelection = false

    @Published private(set) var expense: Expense?
    @Published private(set) var selectedGroup: Groups?
    @Published private(set) var splitData: [String: Double] = [:]

    @Published private(set) var groupMembers: [String] = []
    @Published private(set) var selectedMembers: [String] = []

    @Published private(set) var viewState: ViewState = .initial
    @Published private(set) var splitType: SplitType = .equally

    @Published private(set) var selectedPayers: [String: Double] = [:] {
        didSet {
            updatePayerName()
        }
    }

    private let onDismissSheet: (() -> Void)?
    private let router: Router<AppRoute>

    init(router: Router<AppRoute>, expenseId: String? = nil, onDismissSheet: (() -> Void)? = nil) {
        self.router = router
        self.expenseId = expenseId
        self.onDismissSheet = onDismissSheet

        super.init()

        if let expenseId {
            fetchExpenseDetails(expenseId: expenseId)
        } else {
            fetchDefaultUser()
        }
    }

    // MARK: - Data Loading
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
                self.selectedPayers = [user.id: expenseAmount]
                self.viewState = .initial
            }.store(in: &cancelable)
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
                self.splitType = expense.splitType

                if let splitData = expense.splitData {
                    self.splitData = splitData
                }
                self.selectedMembers = expense.splitTo

                self.fetchGroupData(for: expense.groupId) { group in
                    self.selectedGroup = group
                    self.groupMembers = group?.members ?? []
                    self.selectedPayers = expense.paidBy
                    self.viewState = .initial
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

    // MARK: - Error Handling
    private func handleServerError(_ error: ServiceError) {
        viewState = .initial
        showToastFor(error)
    }
}

// MARK: - User Actions
extension AddExpenseViewModel {

    private func updatePayerName() {
        if selectedPayers.count == 1 {
            if let user = preference.user, selectedPayers.keys.first == user.id {
                payerName = "You"
            } else {
                fetchUserData(for: selectedPayers.keys.first ?? "") { user in
                    self.payerName = user.nameWithLastInitial
                }
            }
        } else {
            payerName = "\(selectedPayers.count) people"
        }
    }

    func handleGroupBtnAction() {
        showGroupSelection = expenseId == nil
    }

    func handleGroupSelection(group: Groups) {
        selectedGroup = group
        groupMembers = group.members
        selectedMembers = group.members
    }

    func handlePayerBtnAction() {
        guard selectedGroup != nil else {
            self.showToastFor(toast: ToastPrompt(type: .warning, title: "Whoops!", message: "Please select group to get payer list."))
            return
        }
        if let user = preference.user, selectedPayers == [:] || selectedPayers[user.id] == 0 {
            selectedPayers = [user.id: expenseAmount]
        }
        showPayerSelection = true
    }

    func handlePayerSelection(payers: [String: Double]) {
        selectedPayers = payers
    }

    func handleSplitTypeBtnAction() {
        guard selectedGroup != nil else {
            showToastFor(toast: ToastPrompt(type: .warning, title: "Whoops!",
                                            message: "Please select group to get payer list."))
            return
        }

        guard expenseAmount > 0 else {
            showToastFor(toast: ToastPrompt(type: .warning, title: "Whoops!",
                                            message: "Please enter a cost for your expense first!"))
            return
        }
        showSplitTypeSelection = true
    }

    func handleSplitTypeSelection(members: [String], splitData: [String: Double], splitType: SplitType) {
        selectedMembers = members
        self.splitData = splitData
        self.splitType = splitType
    }

    func handleSaveAction(completion: @escaping () -> Void) {
        if let user = preference.user, selectedPayers == [:] || selectedPayers[user.id] == 0 {
            selectedPayers = [user.id: expenseAmount]
        }

        if expenseName == "" || expenseAmount == 0 || selectedGroup == nil || selectedPayers == [:] {
            showToastFor(toast: ToastPrompt(type: .warning, title: "Warning",
                                            message: "Please fill all data to add expense."))
            return
        }

        let totalPaidAmount = selectedPayers.map { $0.value }.reduce(0, +)
        let totalSharedAmount = splitData.map { $0.value }.reduce(0, +)

        if (splitType == .fixedAmount && totalSharedAmount != expenseAmount) || (selectedPayers.count > 1 && totalPaidAmount != expenseAmount) {
            let differenceAmount = (splitType == .fixedAmount && totalSharedAmount != expenseAmount) ? totalSharedAmount : totalPaidAmount

            showAlertFor(title: "Error",
                         message: "The total of everyone's paid shares (\(differenceAmount.formattedCurrency)) is different than the total cost (\(expenseAmount.formattedCurrency))")
            return
        }

        guard let selectedGroup, let groupId = selectedGroup.id, let user = preference.user else { return }

        if let expense {
            var newExpense = expense
            newExpense.name = expenseName.trimming(spaces: .leadingAndTrailing).capitalized
            newExpense.amount = expenseAmount
            newExpense.date = Timestamp(date: expenseDate)
            newExpense.paidBy = selectedPayers
            newExpense.splitType = splitType
            newExpense.splitTo = (splitType == .equally) ? selectedMembers : splitData.map({ $0.key })
            newExpense.splitData = splitData

            updateExpense(expense: newExpense)
        } else {
            let expense = Expense(name: expenseName.trimming(spaces: .leadingAndTrailing).capitalized, amount: expenseAmount,
                                  date: Timestamp(date: expenseDate), paidBy: selectedPayers, addedBy: user.id,
                                  splitTo: (splitType == .equally) ? selectedMembers : splitData.map({ $0.key }),
                                  groupId: groupId, splitType: splitType, splitData: splitData)

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
                self?.onDismissSheet?()
            }.store(in: &cancelable)
    }
}

extension AddExpenseViewModel {
    enum ViewState {
        case initial
        case loading
    }

    enum AddExpenseField {
        case expenseName
        case expenseAmount
    }
}
