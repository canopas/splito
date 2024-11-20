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

    @Inject var preference: SplitoPreference
    @Inject var groupRepository: GroupRepository
    @Inject var expenseRepository: ExpenseRepository

    @Published private(set) var groupId: String
    @Published private(set) var overallOwingAmount: Double = 0.0
    @Published private(set) var currentMonthSpending: Double = 0.0

    @Published var group: Groups?
    @Published var groupState: GroupState = .loading

    @Published var expenses: [Expense] = []
    @Published private(set) var memberOwingAmount: [String: Double] = [:]
    @Published private(set) var groupExpenses: [String: [ExpenseWithUser]] = [:]

    @Published var showSettleUpSheet = false
    @Published var showBalancesSheet = false
    @Published var showGroupTotalSheet = false
    @Published var showAddExpenseSheet = false
    @Published var showTransactionsSheet = false
    @Published var showSimplifyInfoSheet = false
    @Published var showInviteMemberSheet = false

    @Published var showSearchBar = false
    @Published var showScrollToTopBtn = false

    @Published var expensesWithUser: [ExpenseWithUser] = [] {
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

    var groupMembers: [AppUser] = []
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
    func fetchGroup() async {
        do {
            let group = try await groupRepository.fetchGroupBy(id: groupId)
            guard let group else {
                groupState = .noMember
                return
            }
            let groupTotalSummary = getTotalSummaryForCurrentMonth(group: group, userId: self.preference.user?.id)
            currentMonthSpending = groupTotalSummary.reduce(0) { $0 + $1.summary.totalShare }

            if self.group?.members != group.members {
                for member in group.members where member != self.preference.user?.id {
                    if let memberData = await self.fetchMemberData(for: member) {
                        self.groupMembers.append(memberData)
                    }
                }
            }

            self.group = group
        } catch {
            handleServiceError()
        }
    }

    func fetchExpenses() async {
        if let state = validateGroupState() {
            groupState = state
            return
        }

        expensesWithUser = []
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

    private func validateGroupState() -> GroupState? {
        guard let userId = preference.user?.id, let group = group else {
            return .noMember
        }

        if !group.isActive && group.members.contains(userId) {
            return .deactivateGroup
        } else if !group.members.contains(userId) {
            return .memberNotInGroup
        }
        return nil
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

        await withTaskGroup(of: ExpenseWithUser?.self) { taskGroup in
            for expense in expenses.uniqued() {
                taskGroup.addTask { [weak self] in
                    guard let self else { return nil }
                    if let user = await self.fetchMemberData(for: expense.paidBy.keys.first ?? "") {
                        return ExpenseWithUser(expense: expense, user: user)
                    }
                    return nil
                }
            }

            for await result in taskGroup {
                if let expenseWithUser = result {
                    combinedData.append(expenseWithUser)
                }
            }
        }

        withAnimation(.easeOut) {
            expensesWithUser.append(contentsOf: combinedData.uniqued())
            fetchGroupBalance()
        }
    }

    func fetchMemberData(for memberId: String) async -> AppUser? {
        do {
            let member = try await groupRepository.fetchMemberBy(userId: memberId)
            if !groupMembers.contains(where: { $0.id == memberId }) {
                if let member {
                    self.groupMembers.append(member)
                }
            }
            return member
        } catch {
            groupState = .noMember
            showToastForError()
            return nil
        }
    }

    func fetchGroupBalance() {
        guard let userId = preference.user?.id, let group else {
            groupState = .noMember
            return
        }

        self.memberOwingAmount = Splito.calculateExpensesSimplified(userId: userId, memberBalances: group.balances)
        withAnimation(.easeOut) {
            overallOwingAmount = self.memberOwingAmount.values.reduce(0, +)
            setGroupViewState()
        }
    }

    private func setGroupViewState() {
        guard let group else {
            groupState = .noMember
            return
        }

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

    // MARK: - Error Handling
    func handleServiceError() {
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
        case deactivateGroup
        case memberNotInGroup
        case noInternet
        case somethingWentWrong
    }
}
