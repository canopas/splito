//
//  GroupHomeViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 06/03/24.
//

import Data
import SwiftUI

class GroupHomeViewModel: BaseViewModel, ObservableObject {

    @Inject private var preference: SplitoPreference
    @Inject private var groupRepository: GroupRepository
    @Inject private var expenseRepository: ExpenseRepository
    @Inject private var transactionRepository: TransactionRepository

    @Published var searchedExpense: String = ""
    @Published private(set) var overallOwingAmount = 0.0

    @Published private(set) var transactions: [Transactions] = []
    @Published private(set) var expensesWithUser: [ExpenseWithUser] = []
    @Published private(set) var memberOwingAmount: [String: Double] = [:]
    @Published private(set) var groupState: GroupState = .loading

    @Published var showSettleUpSheet = false
    @Published var showTransactionsSheet = false
    @Published var showBalancesSheet = false
    @Published var showGroupTotalSheet = false
    @Published private(set) var showSearchBar = false
    @Published var showSimplifyInfoSheet: Bool = false
    @Published private(set) var showScrollToTopBtn = false

    @Published private(set) var group: Groups?

    static private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    var groupExpenses: [String: [ExpenseWithUser]] {
        let filteredExpenses = expensesWithUser.filter { expense in
            searchedExpense.isEmpty ||
            expense.expense.name.lowercased().contains(searchedExpense.lowercased()) ||
            expense.expense.amount == Double(searchedExpense)
        }
        return Dictionary(grouping: filteredExpenses.sorted { $0.expense.date.dateValue() > $1.expense.date.dateValue() }) { expense in
            return GroupHomeViewModel.dateFormatter.string(from: expense.expense.date.dateValue())
        }
    }

    private let groupId: String
    private let router: Router<AppRoute>
    private var expenses: [Expense] = []
    private var groupUserData: [AppUser] = []

    init(router: Router<AppRoute>, groupId: String) {
        self.router = router
        self.groupId = groupId
        super.init()
        self.fetchLatestTransactions()
    }

    private func fetchLatestTransactions() {
        transactionRepository.fetchLatestTransactionsBy(groupId: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] transactions in
                guard let self else { return }
                self.transactions = transactions
                self.fetchLatestExpenses()
            }.store(in: &cancelable)
    }

    private func fetchLatestExpenses() {
        expenseRepository.fetchLatestExpensesBy(groupId: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.groupState = .noMember
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] expenses in
                guard let self, let group else { return }
                self.expenses = expenses
                if group.isDebtSimplified {
                    self.calculateExpensesSimply()
                } else {
                    self.calculateExpenses()
                }
            }.store(in: &cancelable)
    }

    func fetchGroupAndExpenses() {
        groupState = .loading
        groupRepository.fetchGroupBy(id: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.groupState = .noMember
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] group in
                guard let self, let group else { return }
                self.group = group
                for member in group.members where member != self.preference.user?.id {
                    self.fetchUserData(for: member) { memberData in
                        self.groupUserData.append(memberData)
                    }
                }
                self.fetchTransactions()
                self.fetchExpenses()
            }.store(in: &cancelable)
    }

    private func fetchTransactions() {
        transactionRepository.fetchTransactionsBy(groupId: groupId).sink { [weak self] completion in
            if case .failure(let error) = completion {
                self?.showToastFor(error)
            }
        } receiveValue: { [weak self] transactions in
            guard let self else { return }
            self.transactions = transactions
        }.store(in: &cancelable)
    }

    private func fetchExpenses() {
        expenseRepository.fetchExpensesBy(groupId: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.groupState = .noMember
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] expenses in
                guard let self, let group else { return }
                self.expenses = expenses
                if group.isDebtSimplified {
                    self.calculateExpensesSimply()
                } else {
                    self.calculateExpenses()
                }
            }.store(in: &cancelable)
    }

    private func calculateExpenses() {
        guard let userId = preference.user?.id else { return }

        let queue = DispatchGroup()
        var combinedData: [ExpenseWithUser] = []

        var owingAmount: [String: Double] = [:]

        overallOwingAmount = 0.0
        memberOwingAmount = [:]

        for expense in expenses {
            queue.enter()

            let usersSplitAmount = getCalculatedSplitAmount2(member: userId, expense: expense)

            if expense.paidBy.keys.contains(userId) && usersSplitAmount != 0 {
                // If the user paid for the expense, calculate how much each member owes to the user
                if expense.paidBy.count == 1 {
                    for member in expense.splitTo where member != userId {
                        let splitAmount = getCalculatedSplitAmount2(member: member, expense: expense)
                        owingAmount[member, default: 0.0] += splitAmount // Amount user will get back
                    }
                } else {
                    for member in expense.splitTo {
                        let splitAmount = getCalculatedSplitAmount2(member: member, expense: expense)
//                        if !(expense.paidBy.keys.contains(member) && splitAmount > 0) {
                            owingAmount[member, default: 0.0] += splitAmount // Amount user will get back
//                        }
                    }
                }
            } else if expense.splitTo.contains(userId) && usersSplitAmount != 0 {
                // Check if the user is one of the members who should split the expense
                for (payerId, _) in expense.paidBy {
                    let memberId = expense.paidBy.count == 1 ? userId : payerId
                    let splitAmount = getCalculatedSplitAmount2(member: memberId, expense: expense)
                    owingAmount[payerId, default: 0.0] -= splitAmount // Amount user need to pay
                }
            }

            // Fetching only first user data as we are showing payer data for single payer, otherwise we shows payer's count
            fetchUserData(for: expense.paidBy.keys.first ?? "") { user in
                combinedData.append(ExpenseWithUser(expense: expense, user: user))
                queue.leave()
            }
        }

        print("XXX --- All Amount: \(owingAmount)")

        queue.notify(queue: .main) { [weak self] in
            guard let self else { return }
            owingAmount = processTransactions(userId: userId, transactions: self.transactions, memberOwingAmount: owingAmount.filter { $0.key != userId })

            withAnimation(.easeOut) {
                self.memberOwingAmount = owingAmount.filter { $0.value != 0 }
                self.overallOwingAmount = self.memberOwingAmount.values.reduce(0, +)
                self.expensesWithUser = combinedData
            }

            setGroupViewState()
        }
    }

    func calculateTransactions(from owingAmount: [String: Double]) -> [(from: String, to: String, amount: Double)] {
        var positiveBalances: [String: Double] = [:]
        var negativeBalances: [String: Double] = [:]

        // Separate positive and negative balances
        for (member, amount) in owingAmount {
            if amount < 0 {
                negativeBalances[member, default: 0] += amount
            } else if amount > 0 {
                positiveBalances[member, default: 0] += amount
            }
        }

        var transactions: [(from: String, to: String, amount: Double)] = []

        // Calculate payments
        for (debtorName, debtAmount) in negativeBalances {
            var remainingDebt = -debtAmount // convert to positive for calculation

            for (creditorName, creditAmount) in positiveBalances {
                if remainingDebt == 0 { break }

                let paymentAmount = min(remainingDebt, creditAmount)

                transactions.append((from: debtorName, to: creditorName, amount: paymentAmount))

                remainingDebt -= paymentAmount
                positiveBalances[creditorName, default: 0] -= paymentAmount

                // Remove creditor if their balance is zero
                if positiveBalances[creditorName]! <= 0 {
                    positiveBalances.removeValue(forKey: creditorName)
                }
            }
        }

        return transactions
    }

    private func calculateExpensesSimply() {
        guard let userId = preference.user?.id else { return }

        let queue = DispatchGroup()
        var ownAmounts: [String: Double] = [:]
        var combinedData: [ExpenseWithUser] = []

        overallOwingAmount = 0.0
        memberOwingAmount = [:]

        for expense in expenses {
            for (payerId, paidAmount) in expense.paidBy {
                ownAmounts[payerId, default: 0.0] += paidAmount
            }

            for member in expense.splitTo {
                let splitAmount = getCalculatedSplitAmount(member: member, expense: expense)
                ownAmounts[member, default: 0.0] -= splitAmount
            }

            // Fetch user data for each payer once per expense
            queue.enter()
            fetchUserData(for: expense.paidBy.keys.first ?? "") { user in
                combinedData.append(ExpenseWithUser(expense: expense, user: user))
                queue.leave()
            }
        }

        queue.notify(queue: .main) { [weak self] in
            guard let self else { return }
            let debts = settleDebts(users: ownAmounts)
            for debt in debts where debt.0 == userId || debt.1 == userId {
                self.memberOwingAmount[debt.1 == userId ? debt.0 : debt.1] = debt.1 == userId ? debt.2 : -debt.2
            }

            withAnimation(.easeOut) {
                self.memberOwingAmount = processTransactions(userId: userId, transactions: self.transactions, memberOwingAmount: self.memberOwingAmount)
                self.overallOwingAmount = self.memberOwingAmount.values.reduce(0, +)
                self.expensesWithUser = combinedData
            }
            self.setGroupViewState()
        }
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

    private func setGroupViewState() {
        guard let group else { return }
        groupState = group.members.count > 1 ?
        (expenses.isEmpty ? .noExpense : .hasExpense) :
        (expenses.isEmpty ? .noMember : .hasExpense)
    }
}

// MARK: - User Actions
extension GroupHomeViewModel {
    func getMemberDataBy(id: String) -> AppUser? {
        return groupUserData.first(where: { $0.id == id })
    }

    func handleCreateGroupClick() {
        router.push(.CreateGroupView(group: nil))
    }

    func handleAddMemberClick() {
        router.push(.InviteMemberView(groupId: groupId))
    }

    func handleSettingsOptionTap() {
        router.push(.GroupSettingView(groupId: groupId))
    }

    func handleExpenseItemTap(expenseId: String) {
        router.push(.ExpenseDetailView(expenseId: expenseId))
    }

    func handleSettleUpBtnTap() {
        if let group, group.members.count > 1 {
            showSettleUpSheet = true
        } else {
            showAlertFor(title: "Oops", message: "You're the only member in this group, and there's no point in settling up with yourself :)")
        }
    }

    func manageScrollToTopBtnVisibility(_ value: Bool) {
        showScrollToTopBtn = value
    }

    func handleBalancesBtnTap() {
        showBalancesSheet = true
    }

    func handleTotalBtnTap() {
        showGroupTotalSheet = true
    }

    func handleTransactionsBtnTap() {
        showTransactionsSheet = true
    }

    func handleSimplifyInfoSheet() {
        showSimplifyInfoSheet = true
    }

    func dismissSimplifyInfoSheet() {
        showSimplifyInfoSheet = false
    }

    func handleSearchOptionTap() {
        withAnimation {
            searchedExpense = ""
            showSearchBar.toggle()
        }
    }

    func onSearchBarCancelBtnTap() {
        withAnimation {
            searchedExpense = ""
            showSearchBar = false
        }
    }

    func showExpenseDeleteAlert(expenseId: String) {
        showAlert = true
        alert = .init(title: "Delete Expense",
                      message: "Are you sure you want to delete this expense? This will remove this expense for ALL people involved, not just you.",
                      positiveBtnTitle: "Ok",
                      positiveBtnAction: { self.deleteExpense(expenseId: expenseId) },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false })
    }

    private func deleteExpense(expenseId: String) {
        expenseRepository.deleteExpense(id: expenseId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] _ in
                withAnimation { self?.expensesWithUser.removeAll { $0.expense.id == expenseId } }
                self?.showToastFor(toast: .init(type: .success, title: "Success", message: "Expense deleted successfully"))
            }.store(in: &cancelable)
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
