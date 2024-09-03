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

    @Published var searchedExpense: String = ""
    @Published private(set) var groupId: String
    @Published private(set) var overallOwingAmount = 0.0

    @Published var expenses: [Expense] = []
    @Published private(set) var group: Groups?
    @Published private(set) var memberOwingAmount: [String: Double] = [:]
    @Published private(set) var groupState: GroupState = .loading

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

    static private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    @Published private(set) var expensesWithUser: [ExpenseWithUser] = [] {
        didSet {
            let filteredExpenses = expensesWithUser.filter { expense in
                searchedExpense.isEmpty ||
                expense.expense.name.lowercased().contains(searchedExpense.lowercased()) ||
                expense.expense.amount == Double(searchedExpense)
            }
            groupExpenses = Dictionary(grouping: filteredExpenses) { expense in
                return GroupHomeViewModel.dateFormatter.string(from: expense.expense.date.dateValue())
            }
        }
    }

    var groupExpenses: [String: [ExpenseWithUser]] = [:]

    var currentMonthSpendingAmount: Double {
        guard let userId = preference.user?.id else { return 0 }

        return currentMonthExpenses
            .filter { expense in
                expense.splitTo.contains(userId) // Check if the user is involved in the expense
            }
            .map { $0.getTotalSplitAmountOf(member: userId) }
            .reduce(0.0, +)
    }

    let router: Router<AppRoute>
    var hasMoreExpenses: Bool = true
    private var lastDocument: DocumentSnapshot?

    private var hasLoadedInitially = true
    private var groupUserData: [AppUser] = []
    private var currentMonthExpenses: [Expense] = []

    init(router: Router<AppRoute>, groupId: String) {
        self.router = router
        self.groupId = groupId
        super.init()

        fetchGroupAndExpenses()
        fetchCurrentMonthExpenses()
    }

    // MARK: - Data Loading
    private func fetchGroupAndExpenses() {
        groupRepository.fetchLatestGroupBy(id: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.groupState = .noMember
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] group in
                guard let self, let group else { return }
                self.group = group

                if self.hasLoadedInitially {
                    for member in group.members where member != self.preference.user?.id {
                        self.fetchUserData(for: member) { memberData in
                            self.groupUserData.append(memberData)
                        }
                    }
                    self.hasLoadedInitially = false
                }

                self.fetchExpenses()
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

                self.combineMemberWithExpense(expenses: result.expenses)
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

                self.combineMemberWithExpense(expenses: result.expenses)
                self.hasMoreExpenses = !(result.expenses.count < self.EXPENSES_LIMIT)
            }.store(in: &cancelable)
    }

    private func combineMemberWithExpense(expenses: [Expense]) {
        let queue = DispatchGroup()
        var combinedData: [ExpenseWithUser] = []

        for expense in expenses {
            queue.enter()
            fetchUserData(for: expense.paidBy.keys.first ?? "") { user in
                combinedData.append(ExpenseWithUser(expense: expense, user: user))
                queue.leave()
            }
        }

        queue.notify(queue: .main) { [weak self] in
            withAnimation(.easeOut) {
                self?.expensesWithUser.append(contentsOf: combinedData)
                self?.fetchGroupBalance()
            }
        }
    }

    private func fetchCurrentMonthExpenses() {
        expenseRepository.fetchCurrentMonthExpensesBy(groupId: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] expenses in
                self?.currentMonthExpenses = expenses.uniqued()
            }.store(in: &cancelable)
    }

    private func fetchUserData(for userId: String, completion: @escaping (AppUser) -> Void) {
        groupRepository.fetchMemberBy(userId: userId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.showToastFor(error)
                }
            } receiveValue: { user in
                guard let user else { return }
                completion(user)
            }.store(in: &cancelable)
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
        router.push(.ExpenseDetailView(groupId: groupId, expenseId: expenseId, groupImageUrl: group?.imageUrl ?? ""))
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
            } receiveValue: { [weak self] _ in
                self?.showToastFor(toast: .init(type: .success, title: "Success", message: "Expense deleted successfully."))
            }.store(in: &cancelable)
    }

    func openAddExpenseSheet() {
        showAddExpenseSheet = true
    }

    func dismissShowSettleUpSheet() {
        showToastFor(toast: .init(type: .success, title: "Success", message: "Payment made successfully"))
        showSettleUpSheet = false
    }
}

// MARK: - Helper Methods
extension GroupHomeViewModel {
    func sortMonthYearStrings(_ s1: String, _ s2: String) -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"

        guard let date1 = dateFormatter.date(from: s1),
              let date2 = dateFormatter.date(from: s2) else {
            return false
        }

        let components1 = Calendar.current.dateComponents([.year, .month], from: date1)
        let components2 = Calendar.current.dateComponents([.year, .month], from: date2)

        // Compare years first
        if components1.year != components2.year {
            return (components1.year ?? 0) > (components2.year ?? 0)
        }
        // If years are the same, compare months
        else {
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
struct ExpenseWithUser {
    let expense: Expense
    let user: AppUser
}
