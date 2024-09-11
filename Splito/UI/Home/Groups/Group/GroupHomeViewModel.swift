//
//  GroupHomeViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 06/03/24.
//

import Data
import SwiftUI
import BaseStyle
import FirebaseFirestore

class GroupHomeViewModel: BaseViewModel, ObservableObject {

    private let EXPENSES_LIMIT = 10

    @Inject private var preference: SplitoPreference
    @Inject private var groupRepository: GroupRepository
    @Inject private var expenseRepository: ExpenseRepository

    @Published private(set) var groupId: String
    @Published private(set) var overallOwingAmount: Double = 0.0
    @Published private(set) var currentMonthSpending: Double = 0.0

    @Published private(set) var group: Groups?
    @Published private(set) var groupState: GroupState = .loading

    @Published private(set) var expenses: [Expense] = []
    @Published private(set) var memberOwingAmount: [String: Double] = [:]
    @Published private(set) var groupExpenses: [String: [ExpenseWithUser]] = [:]

    @Published var showSettleUpSheet = false
    @Published var showBalancesSheet = false
    @Published var showGroupTotalSheet = false
    @Published var showAddExpenseSheet = false
    @Published var showTransactionsSheet = false
    @Published var showSimplifyInfoSheet = false
    @Published var showInviteMemberSheet = false

    @Published private(set) var showSearchBar = false
    @Published private(set) var showScrollToTopBtn = false
    @Published private(set) var showAddExpenseBtn = false

    @Published private(set) var expensesWithUser: [ExpenseWithUser] = [] {
        didSet {
            updateGroupExpenses()
        }
    }

    @Published var searchedExpense: String = "" {
        didSet {
            updateGroupExpenses()
        }
    }

    static private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    let router: Router<AppRoute>
    var hasMoreExpenses: Bool = true

    private var groupUserData: [AppUser] = []
    private var lastDocument: DocumentSnapshot?

    init(router: Router<AppRoute>, groupId: String) {
        self.router = router
        self.groupId = groupId
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(handleAddExpense(notification:)), name: .addExpense, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleUpdateExpense(notification:)), name: .updateExpense, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDeleteExpense(notification:)), name: .deleteExpense, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAddTransaction(notification:)), name: .addTransaction, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleTransaction(notification:)), name: .updateTransaction, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleTransaction(notification:)), name: .deleteTransaction, object: nil)

        fetchGroup()
        fetchExpenses()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Data Loading
    private func fetchGroup() {
        groupRepository.fetchGroupBy(id: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.groupState = .noMember
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] group in
                guard let self, let group else { return }
                let groupTotalSummary = getTotalSummaryForCurrentMonth(group: group, userId: preference.user?.id)
                self.currentMonthSpending = groupTotalSummary.reduce(0) { $0 + $1.summary.totalShare }

                if self.group?.members != group.members {
                    for member in group.members where member != self.preference.user?.id {
                        self.fetchUserData(for: member) { memberData in
                            self.groupUserData.append(memberData)
                        }
                    }
                }

                NotificationCenter.default.post(name: .updateGroup, object: group)
                self.group = group
                self.combineMemberWithExpense(expenses: self.expenses)
            }.store(in: &cancelable)
    }

    func fetchExpenses() {
        expensesWithUser = []
        expenseRepository.fetchExpensesBy(groupId: groupId, limit: EXPENSES_LIMIT)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.groupState = .noMember
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] result in
                guard let self else { return }
                self.lastDocument = result.lastDocument
                self.expenses = result.expenses.uniqued()

                self.combineMemberWithExpense(expenses: result.expenses.uniqued())
                self.hasMoreExpenses = !(result.expenses.count < self.EXPENSES_LIMIT)
            }.store(in: &cancelable)
    }

    func fetchMoreExpenses() {
        guard hasMoreExpenses else { return }

        expenseRepository.fetchExpensesBy(groupId: groupId, limit: EXPENSES_LIMIT, lastDocument: lastDocument)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.groupState = .noMember
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] result in
                guard let self else { return }
                self.lastDocument = result.lastDocument
                self.expenses.append(contentsOf: result.expenses.uniqued())

                self.combineMemberWithExpense(expenses: result.expenses.uniqued())
                self.hasMoreExpenses = !(result.expenses.count < self.EXPENSES_LIMIT)
            }.store(in: &cancelable)
    }

    private func combineMemberWithExpense(expenses: [Expense]) {
        let queue = DispatchGroup()
        var combinedData: [ExpenseWithUser] = []

        for expense in expenses.uniqued() {
            queue.enter()
            fetchUserData(for: expense.paidBy.keys.first ?? "") { user in
                combinedData.append(ExpenseWithUser(expense: expense, user: user))
                queue.leave()
            }
        }

        queue.notify(queue: .main) { [weak self] in
            withAnimation(.easeOut) {
                self?.expensesWithUser.append(contentsOf: combinedData.uniqued())
                self?.fetchGroupBalance()
            }
        }
    }

    private func fetchUserData(for userId: String, completion: @escaping (AppUser) -> Void) {
        if let existingUser = groupUserData.first(where: { $0.id == userId }) {
            return completion(existingUser) // Return the available user from groupUserData
        } else {
            groupRepository.fetchMemberBy(userId: userId)
                .sink { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.showToastFor(error)
                    }
                } receiveValue: { user in
                    guard let user else { return }
                    self.groupUserData.append(user)
                    completion(user)
                }.store(in: &cancelable)
        }
    }

    private func fetchGroupBalance() {
        guard let userId = preference.user?.id, let group else { return }

        memberOwingAmount = Splito.calculateExpensesSimplified(userId: userId, memberBalances: group.balances)
        withAnimation(.easeOut) {
            overallOwingAmount = memberOwingAmount.values.reduce(0, +)
            setGroupViewState()
        }
    }

    private func setGroupViewState() {
        guard let group else { return }
        groupState = group.members.count > 1 ?
        ((expenses.isEmpty && group.balances.allSatisfy({ $0.balance == 0 })) ? .noExpense : .hasExpense) : (expenses.isEmpty ? .noMember : .hasExpense)
    }

    private func updateGroupExpenses() {
        let filteredExpenses = expensesWithUser.uniqued().filter { expense in
            searchedExpense.isEmpty ||
            expense.expense.name.lowercased().contains(searchedExpense.lowercased()) ||
            expense.expense.amount == Double(searchedExpense)
        }
        groupExpenses = Dictionary(grouping: filteredExpenses.uniqued().sorted { $0.expense.date.dateValue() > $1.expense.date.dateValue() }) { expense in
            return GroupHomeViewModel.dateFormatter.string(from: expense.expense.date.dateValue())
        }
    }
}

// MARK: - User Actions
extension GroupHomeViewModel {
    func getMemberDataBy(id: String) -> AppUser? {
        return groupUserData.first(where: { $0.id == id })
    }

    func handleInviteMemberClick() {
        showInviteMemberSheet = true
    }

    func handleSettingsOptionTap() {
        router.push(.GroupSettingView(groupId: groupId))
    }

    func handleExpenseItemTap(expenseId: String) {
        router.push(.ExpenseDetailView(groupId: groupId, expenseId: expenseId))
    }

    func handleSettleUpBtnTap() {
        if let group, group.members.count > 1 {
            showSettleUpSheet = true
            onSearchBarCancelBtnTap()
        } else {
            showAlertFor(title: "Oops", message: "You're the only member in this group, and there's no point in settling up with yourself :)")
        }
    }

    func manageScrollToTopBtnVisibility(_ value: Bool) {
        showScrollToTopBtn = value
    }

    func handleBalancesBtnTap() {
        showBalancesSheet = true
        onSearchBarCancelBtnTap()
    }

    func handleTotalBtnTap() {
        showGroupTotalSheet = true
        onSearchBarCancelBtnTap()
    }

    func handleTransactionsBtnTap() {
        showTransactionsSheet = true
        onSearchBarCancelBtnTap()
    }

    func handleSimplifyInfoSheet() {
        UIApplication.shared.endEditing()
        showSimplifyInfoSheet = true
    }

    func handleSearchOptionTap() {
        if expenses.isEmpty {
            self.showToastFor(toast: ToastPrompt(type: .info, title: "Whoops!", message: "Add an expense first to use the search functionality."))
            return
        }
        withAnimation {
            searchedExpense = ""
            showSearchBar.toggle()
        }
    }

    func onSearchBarCancelBtnTap() {
        if showSearchBar {
            withAnimation {
                searchedExpense = ""
                showSearchBar = false
            }
        }
    }

    func showExpenseDeleteAlert(expense: Expense) {
        showAlert = true
        alert = .init(title: "Delete Expense",
                      message: "Are you sure you want to delete this expense? This will remove this expense for ALL people involved, not just you.",
                      positiveBtnTitle: "Ok",
                      positiveBtnAction: { self.deleteExpense(expense: expense) },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false })
    }

    private func deleteExpense(expense: Expense) {
        expenseRepository.deleteExpense(groupId: groupId, expenseId: expense.id ?? "")
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] _ in
                self?.updateGroupMemberBalance(expense: expense, updateType: .Delete)
            }.store(in: &cancelable)
    }

    private func updateGroupMemberBalance(expense: Expense, updateType: ExpenseUpdateType) {
        guard var group else { return }
        let memberBalance = getUpdatedMemberBalanceFor(expense: expense, group: group, updateType: updateType)
        group.balances = memberBalance

        groupRepository.updateGroup(group: group)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.showToastFor(error)
                }
            } receiveValue: { _ in
                NotificationCenter.default.post(name: .deleteExpense, object: expense)
            }.store(in: &cancelable)
    }

    func openAddExpenseSheet() {
        showAddExpenseSheet = true
    }

    @objc private func handleAddExpense(notification: Notification) {
        guard let newExpense = notification.object as? Expense else { return }

        expenses.append(newExpense)
        fetchUserData(for: newExpense.paidBy.keys.first ?? "") { [weak self] user in
            let newExpenseWithUser = ExpenseWithUser(expense: newExpense, user: user)
            withAnimation {
                self?.expensesWithUser.append(newExpenseWithUser)
            }
        }
        fetchGroup()
    }

    @objc private func handleUpdateExpense(notification: Notification) {
        guard let updatedExpense = notification.object as? Expense else { return }

        if let index = expenses.firstIndex(where: { $0.id == updatedExpense.id }) {
            self.expenses[index] = updatedExpense
        }
        fetchUserData(for: updatedExpense.paidBy.keys.first ?? "") { [weak self] user in
            guard let self = self else { return }

            if let index = self.expensesWithUser.firstIndex(where: { $0.expense.id == updatedExpense.id }) {
                let updatedExpenseWithUser = ExpenseWithUser(expense: updatedExpense, user: user)
                withAnimation {
                    self.expensesWithUser[index] = updatedExpenseWithUser
                }
            }
        }
        fetchGroup()
    }

    @objc private func handleDeleteExpense(notification: Notification) {
        guard let deletedExpense = notification.object as? Expense else { return }

        expenses.removeAll { $0.id == deletedExpense.id }
        if let index = expensesWithUser.firstIndex(where: { $0.expense.id == deletedExpense.id }) {
            withAnimation {
                expensesWithUser.remove(at: index)
                showToastFor(toast: .init(type: .success, title: "Success", message: "Expense deleted successfully."))
            }
        }
        fetchGroup()
    }

    @objc private func handleTransaction(notification: Notification) {
        fetchGroup()
    }

    @objc private func handleAddTransaction(notification: Notification) {
        showToastFor(toast: .init(type: .success, title: "Success", message: "Payment made successfully"))
        showSettleUpSheet = false
        fetchGroup()
    }
}

// MARK: - Helper Methods
extension GroupHomeViewModel {
    func sortMonthYearStrings(_ s1: String, _ s2: String) -> Bool {
        guard let date1 = GroupHomeViewModel.dateFormatter.date(from: s1),
              let date2 = GroupHomeViewModel.dateFormatter.date(from: s2) else {
            return false
        }

        let components1 = Calendar.current.dateComponents([.year, .month], from: date1)
        let components2 = Calendar.current.dateComponents([.year, .month], from: date2)

        // Compare years first
        if components1.year != components2.year {
            return (components1.year ?? 0) > (components2.year ?? 0)
        } else {    // If years are the same, compare months
            return (components1.month ?? 0) > (components2.month ?? 0)
        }
    }
}

// MARK: - Group State
extension GroupHomeViewModel {
    enum GroupState {
        case loading
        case noMember
        case noExpense
        case hasExpense
    }
}

// Struct to hold combined expense and user information
struct ExpenseWithUser: Hashable {
    let expense: Expense
    let user: AppUser
}
