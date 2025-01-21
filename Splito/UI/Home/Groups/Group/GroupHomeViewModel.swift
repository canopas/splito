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
    let GROUP_REPORT_FILE_NAME = "Splito group report \(Date().shortDate).csv"

    @Inject var preference: SplitoPreference
    @Inject var groupRepository: GroupRepository
    @Inject var expenseRepository: ExpenseRepository
    @Inject var transactionRepository: TransactionRepository

    @Published var group: Groups?
    @Published var groupReportUrl: URL?
    @Published private(set) var groupId: String

    @Published var transactionsCount: Int = 0
    @Published private(set) var overallOwingAmount: Double = 0.0
    @Published private(set) var currentMonthSpending: Double = 0.0

    @Published var groupState: GroupState = .loading

    @Published var expenses: [Expense] = []
    @Published var expensesWithUser: [ExpenseWithUser] = []
    @Published private(set) var memberOwingAmount: [String: Double] = [:]
    @Published private(set) var groupExpenses: [String: [ExpenseWithUser]] = [:]

    @Published var showSearchBar = false
    @Published var showSettleUpSheet = false
    @Published var showBalancesSheet = false
    @Published var showExportOptions = false
    @Published var showScrollToTopBtn = false
    @Published var showGroupTotalSheet = false
    @Published var showAddExpenseSheet = false
    @Published var showShareReportSheet = false
    @Published var showTransactionsSheet = false
    @Published var showSimplifyInfoSheet = false
    @Published var showInviteMemberSheet = false

    @Published var searchedExpense: String = "" {
        didSet {
            updateGroupExpenses()
        }
    }

    let router: Router<AppRoute>
    var hasMoreExpenses: Bool = true
    private var isInitialDataLoaded = false

    var groupMembers: [AppUser] = []
    private var lastDocument: DocumentSnapshot?
    var groupTask: Task<Void, Never>? // To manage the lifecycle of the async stream
    var exportTask: Task<Void, Never>? // Reference to hold the current export task

    init(router: Router<AppRoute>, groupId: String) {
        self.router = router
        self.groupId = groupId
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(handleAddExpense(notification:)), name: .addExpense, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleUpdateExpense(notification:)), name: .updateExpense, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDeleteExpense(notification:)), name: .deleteExpense, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAddTransaction(notification:)), name: .addTransaction, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleUpdateGroup(notification:)), name: .updateGroup, object: nil)

        fetchGroupAndExpenses()
        observeGroupLatestData()
    }

    deinit {
        groupTask?.cancel()
    }

    func fetchGroupAndExpenses(needToReload: Bool = false) {
        lastDocument = nil
        Task { [weak self] in
            guard let self else { return }
            await self.fetchGroup()
            await self.getTransactionsCount()
            await self.fetchExpenses(needToReload: needToReload)
        }
    }

    // MARK: - Data Loading
    private func fetchGroup() async {
        do {
            let group = try await groupRepository.fetchGroupBy(id: groupId)
            guard let group else {
                groupState = .noMember
                return
            }

            self.group = group
            let groupTotalSummary = getTotalSummaryForCurrentMonth(group: group, userId: self.preference.user?.id)
            currentMonthSpending = groupTotalSummary.reduce(0) { $0 + $1.summary.totalShare }

            await withTaskGroup(of: Void.self) { groupTask in
                for member in group.members where member != preference.user?.id {
                    groupTask.addTask { [weak self] in
                        _ = await self?.fetchMemberData(for: member)
                    }
                }
            }

            LogD("GroupHomeViewModel: \(#function) Group fetched successfully.")
        } catch {
            LogE("GroupHomeViewModel: \(#function) Failed to fetch group \(groupId): \(error).")
            handleServiceError()
        }
    }

    private func observeGroupLatestData() {
        let groupStream = groupRepository.streamLatestGroupDataBy(id: groupId)
        Task { [weak self] in
            for await group in groupStream {
                guard let self else { return }
                guard let group else {
                    self.groupState = .noMember
                    return
                }

                self.group = group
                let groupTotalSummary = getTotalSummaryForCurrentMonth(group: group, userId: self.preference.user?.id)
                self.currentMonthSpending = groupTotalSummary.reduce(0) { $0 + $1.summary.totalShare }

                await withTaskGroup(of: Void.self) { taskGroup in
                    for member in group.members where member != self.preference.user?.id {
                        taskGroup.addTask { [weak self] in
                            guard let self else { return }
                            _ = await self.fetchMemberData(for: member)
                        }
                    }
                }

                if self.isInitialDataLoaded {
                    self.setGroupBalanceWithState()
                }
                self.isInitialDataLoaded = true
            }
        }
    }

    func refetchTransactionsCount() {
        Task { [weak self] in
            await self?.getTransactionsCount()
            self?.setGroupViewState()
        }
    }

    private func getTransactionsCount() async {
        if let state = validateGroupState() {
            groupState = state
            return
        }

        do {
            let count = try await transactionRepository.getTransactionsCount(groupId: groupId)
            transactionsCount = count
            LogD("GroupHomeViewModel: \(#function) Transactions count fetched successfully.")
        } catch {
            LogE("GroupHomeViewModel: \(#function) Failed to fetch payment count: \(error).")
            handleServiceError()
        }
    }

    private func fetchExpenses(needToReload: Bool = false) async {
        if let state = validateGroupState() {
            groupState = state
            return
        }
        guard hasMoreExpenses || needToReload else {
            groupState = .noMember
            return
        }
        if lastDocument == nil {
            expensesWithUser = []
        }

        do {
            let result = try await expenseRepository.fetchExpensesBy(groupId: groupId, limit: EXPENSES_LIMIT, lastDocument: lastDocument)
            expenses = lastDocument == nil ? result.expenses.uniqued() : (expenses + result.expenses.uniqued())
            lastDocument = result.lastDocument

            await combineMemberWithExpense(expenses: result.expenses.uniqued())
            hasMoreExpenses = !(result.expenses.count < self.EXPENSES_LIMIT)
            LogD("GroupHomeViewModel: \(#function) Expenses fetched successfully.")
        } catch {
            LogE("GroupHomeViewModel: \(#function) Failed to fetch expenses: \(error).")
            handleErrorState()
        }
    }

    private func validateGroupState() -> GroupState? {
        guard let userId = preference.user?.id, let group else {
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
        Task { [weak self] in
            await self?.fetchExpenses()
        }
    }

    private func combineMemberWithExpense(expenses: [Expense]) async {
        var combinedData: [ExpenseWithUser] = []

        await withTaskGroup(of: ExpenseWithUser?.self) { taskGroup in
            for expense in expenses.uniqued() {
                taskGroup.addTask { [weak self] in
                    if let user = await self?.fetchMemberData(for: expense.paidBy.keys.first ?? "") {
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
            updateGroupExpenses()
            setGroupBalanceWithState()
        }
    }

    func fetchMemberData(for memberId: String) async -> AppUser? {
        do {
            let fetchedMember = getMemberDataBy(id: memberId)
            guard fetchedMember == nil else {
                LogD("GroupHomeViewModel: \(#function) Fetched Member is already exists.")
                return fetchedMember
            }
            let member = try await groupRepository.fetchMemberBy(memberId: memberId)
            if let member {
                groupMembers.append(member)
                LogD("GroupHomeViewModel: \(#function) Member fetched successfully.")
            }
            return member
        } catch {
            groupState = .noMember
            LogE("GroupHomeViewModel: \(#function) Failed to fetch member \(memberId): \(error).")
            showToastForError()
            return nil
        }
    }

    func updateGroupExpenses() {
        let filteredExpenses = expensesWithUser.uniqued().filter { expense in
            searchedExpense.isEmpty ||
            expense.expense.name.lowercased().contains(searchedExpense.lowercased()) ||
            expense.expense.amount == Double(searchedExpense)
        }
        groupExpenses = Dictionary(grouping: filteredExpenses.uniqued().sorted { $0.expense.date.dateValue() > $1.expense.date.dateValue() }) { expense in
            return expense.expense.date.dateValue().monthWithYear
        }
    }

    func setGroupBalanceWithState() {
        guard let userId = preference.user?.id, let group else {
            groupState = .noMember
            return
        }

        memberOwingAmount = Splito.calculateExpensesSimplified(userId: userId, memberBalances: group.balances)
        withAnimation(.easeOut) {
            overallOwingAmount = group.balances.first(where: { $0.id == userId })?.balance ?? 0.0
            setGroupViewState()
        }
    }

    private func setGroupViewState() {
        guard let group else {
            groupState = .noMember
            return
        }

        groupState = group.members.count > 1 ?
        ((expenses.isEmpty && transactionsCount <= 0) ? .noExpense : .hasExpense) :
        ((expenses.isEmpty && transactionsCount <= 0) ? .noMember : .hasExpense)
    }

    // MARK: - Error Handling
    func handleServiceError() {
        if !networkMonitor.isConnected {
            groupState = .noInternet
        } else {
            groupState = .somethingWentWrong
        }
    }

    private func handleErrorState() {
        if lastDocument == nil {
            handleServiceError()
        } else {
            groupState = .noMember
            showToastForError()
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

// MARK: - Export Options
enum ExportOptions: Int, CaseIterable {

    case month, threeMonths, sixMonths, year, all

    var option: String {
        switch self {
        case .month:
            return "Month"
        case .threeMonths:
            return "Three months"
        case .sixMonths:
            return "Six months"
        case .year:
            return "Year"
        case .all:
            return "All"
        }
    }
}
