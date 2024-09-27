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
        NotificationCenter.default.addObserver(self, selector: #selector(handleUpdateGroup(notification:)), name: .updateGroup, object: nil)

        fetchGroupAndExpenses()
    }

    func fetchGroupAndExpenses() {
        Task {
            await fetchGroup()
            await fetchExpenses()
        }
    }

    // MARK: - Data Loading
    private func fetchGroup() async {
        do {
            let group = try await groupRepository.fetchGroupBy(id: groupId)
            guard let group else { return }
            let groupTotalSummary = getTotalSummaryForCurrentMonth(group: group, userId: self.preference.user?.id)
            currentMonthSpending = groupTotalSummary.reduce(0) { $0 + $1.summary.totalShare }

            if self.group?.members != group.members {
                for member in group.members where member != self.preference.user?.id {
                    if let memberData = await self.fetchUserData(for: member) {
                        self.groupUserData.append(memberData)
                    }
                }
            }

            self.group = group
        } catch {
            handleServiceError()
        }
    }

    func fetchExpenses() async {
        self.expensesWithUser = []

        do {
            let result = try await expenseRepository.fetchExpensesBy(groupId: groupId, limit: EXPENSES_LIMIT)
            lastDocument = result.lastDocument
            expenses = result.expenses.uniqued()

            await combineMemberWithExpense(expenses: result.expenses.uniqued())
            hasMoreExpenses = !(result.expenses.count < self.EXPENSES_LIMIT)
        } catch {
            handleServiceError()
        }
    }

    func loadMoreExpenses() {
        Task {
            await fetchMoreExpenses()
        }
    }

    private func fetchMoreExpenses() async {
        guard hasMoreExpenses else { return }

        do {
            let result = try await expenseRepository.fetchExpensesBy(groupId: groupId, limit: EXPENSES_LIMIT, lastDocument: lastDocument)
            lastDocument = result.lastDocument
            expenses.append(contentsOf: result.expenses.uniqued())

            await combineMemberWithExpense(expenses: result.expenses.uniqued())
            hasMoreExpenses = !(result.expenses.count < EXPENSES_LIMIT)
        } catch {
            showToastForError()
        }
    }

    private func combineMemberWithExpense(expenses: [Expense]) async {
        var combinedData: [ExpenseWithUser] = []

        for expense in expenses.uniqued() {
            if let user = await fetchUserData(for: expense.paidBy.keys.first ?? "") {
                combinedData.append(ExpenseWithUser(expense: expense, user: user))
            }
        }

        withAnimation(.easeOut) {
            expensesWithUser.append(contentsOf: combinedData.uniqued())
            fetchGroupBalance()
        }
    }

    private func fetchUserData(for userId: String) async -> AppUser? {
        if let existingUser = groupUserData.first(where: { $0.id == userId }) {
            return existingUser // Return the available user from groupUserData
        } else {
            do {
                let user = try await groupRepository.fetchMemberBy(userId: userId)
                if let user {
                    self.groupUserData.append(user)
                }
                return user
            } catch {
                showToastForError()
                return nil
            }
        }
    }

    private func fetchGroupBalance() {
        guard let userId = preference.user?.id, let group else { return }

        self.memberOwingAmount = Splito.calculateExpensesSimplified(userId: userId, memberBalances: group.balances)
        withAnimation(.easeOut) {
            overallOwingAmount = self.memberOwingAmount.values.reduce(0, +)
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
        self.groupExpenses = Dictionary(grouping: filteredExpenses.uniqued().sorted { $0.expense.date.dateValue() > $1.expense.date.dateValue() }) { expense in
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
                      positiveBtnAction: {
                        Task {
                            await self.deleteExpense(expense: expense)
                        }
                      },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false })
    }

    private func deleteExpense(expense: Expense) async {
        do {
            try await expenseRepository.deleteExpense(groupId: groupId, expenseId: expense.id ?? "")
            await updateGroupMemberBalance(expense: expense, updateType: .Delete)
        } catch {
            showToastForError()
        }
    }

    private func updateGroupMemberBalance(expense: Expense, updateType: ExpenseUpdateType) async {
        guard var group else { return }
        let memberBalance = getUpdatedMemberBalanceFor(expense: expense, group: group, updateType: updateType)
        group.balances = memberBalance

        do {
            try await groupRepository.updateGroup(group: group)
            NotificationCenter.default.post(name: .deleteExpense, object: expense)
        } catch {
            showToastForError()
        }
    }

    func openAddExpenseSheet() {
        showAddExpenseSheet = true
    }

    @objc private func handleAddExpense(notification: Notification) {
        guard let newExpense = notification.object as? Expense, newExpense.groupId == groupId else { return }
        Task {
            expenses.append(newExpense)
            if let user = await fetchUserData(for: newExpense.paidBy.keys.first ?? "") {
                let newExpenseWithUser = ExpenseWithUser(expense: newExpense, user: user)
                withAnimation {
                    expensesWithUser.append(newExpenseWithUser)
                }
            }
        }
        refreshGroupData()
    }

    @objc private func handleUpdateExpense(notification: Notification) {
        guard let updatedExpense = notification.object as? Expense else { return }

        if let index = expenses.firstIndex(where: { $0.id == updatedExpense.id }) {
            expenses[index] = updatedExpense
        }

        Task {
            if let user = await fetchUserData(for: updatedExpense.paidBy.keys.first ?? "") {
                if let index = expensesWithUser.firstIndex(where: { $0.expense.id == updatedExpense.id }) {
                    let updatedExpenseWithUser = ExpenseWithUser(expense: updatedExpense, user: user)
                    withAnimation {
                        expensesWithUser[index] = updatedExpenseWithUser
                    }
                }
            }
        }
        refreshGroupData()
    }

    @objc private func handleDeleteExpense(notification: Notification) {
        guard let deletedExpense = notification.object as? Expense else { return }
        expenses.removeAll { $0.id == deletedExpense.id }
        if let index = expensesWithUser.firstIndex(where: { $0.expense.id == deletedExpense.id }) {
            withAnimation {
                self.expensesWithUser.remove(at: index)
                self.showToastFor(toast: .init(type: .success, title: "Success", message: "Expense deleted successfully."))
            }
        }
        refreshGroupData()
    }

    @objc private func handleTransaction(notification: Notification) {
        refreshGroupData()
    }

    @objc private func handleAddTransaction(notification: Notification) {
        showToastFor(toast: .init(type: .success, title: "Success", message: "Payment made successfully"))
        showSettleUpSheet = false
        refreshGroupData()
    }

    @objc private func handleUpdateGroup(notification: Notification) {
        guard let updatedGroup = notification.object as? Groups else { return }
        group?.name = updatedGroup.name
    }

    private func refreshGroupData() {
        Task {
            await fetchGroup()
            fetchGroupBalance()
            NotificationCenter.default.post(name: .updateGroup, object: group)
        }
    }

    // MARK: - Error Handling
    private func handleServiceError() {
        if !networkMonitor.isConnected {
            groupState = .noInternet
        } else {
            groupState = .somethingWentWrong
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
        case noInternet
        case somethingWentWrong
    }
}
