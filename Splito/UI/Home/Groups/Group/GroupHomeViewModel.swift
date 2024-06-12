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

    @Published private var expenses: [Expense] = []
    @Published var expensesWithUser: [ExpenseWithUser] = []
    @Published var groupState: GroupState = .noMember

    @Published var overallOwingAmount = 0.0
    @Published var searchedExpense: String = ""
    @Published var memberOwingAmount: [String: Double] = [:]

    @Published var showSettleUpSheet = false
    @Published var showBalancesSheet = false
    @Published var showGroupTotalSheet = false
    @Published private(set) var showSearchBar = false

    @Published var group: Groups?

    var groupExpenses: [String: [ExpenseWithUser]] {
        let filteredExpenses = expensesWithUser.filter { expense in
            searchedExpense.isEmpty || expense.expense.name.lowercased().contains(searchedExpense.lowercased())
        }

        return Dictionary(grouping: filteredExpenses.sorted { $0.expense.date.dateValue() > $1.expense.date.dateValue() }) { expense in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM yyyy"
            return dateFormatter.string(from: expense.expense.date.dateValue())
        }
    }

    private let groupId: String
    private var groupUserData: [AppUser] = []
    private let router: Router<AppRoute>

    init(router: Router<AppRoute>, groupId: String) {
        self.router = router
        self.groupId = groupId
        super.init()
        self.fetchLatestExpenses()
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
                self.fetchExpenses()
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
                guard let self, let group, self.expenses.isEmpty else { return }
                self.expenses = expenses
                if group.isDebtSimplified {
                    self.calculateExpensesSimply()
                } else {
                    self.calculateExpenses()
                }
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
        guard let userId = self.preference.user?.id else { return }

        let queue = DispatchGroup()
        var expenseByUser = 0.0
        var combinedData: [ExpenseWithUser] = []

        var owesToUser: [String: Double] = [:]
        var owedByUser: [String: Double] = [:]

        overallOwingAmount = 0.0
        memberOwingAmount = [:]

        for expense in expenses {
            queue.enter()

            let splitAmount = expense.amount / Double(expense.splitTo.count)

            if expense.paidBy == userId {
                expenseByUser += expense.splitTo.contains(userId) ? expense.amount - splitAmount : expense.amount
                for member in expense.splitTo where member != userId {
                    owesToUser[member, default: 0.0] += splitAmount
                }
            } else if expense.splitTo.contains(where: { $0 == userId }) {
                expenseByUser -= splitAmount
                owedByUser[expense.paidBy, default: 0.0] += splitAmount
            }

            self.fetchUserData(for: expense.paidBy) { user in
                combinedData.append(ExpenseWithUser(expense: expense, user: user))
                queue.leave()
            }
        }

        queue.notify(queue: .main) {
            owesToUser.forEach { userId, owesAmount in
                self.memberOwingAmount[userId] = owesAmount
            }
            owedByUser.forEach { userId, owedAmount in
                self.memberOwingAmount[userId] = (self.memberOwingAmount[userId] ?? 0) - owedAmount
            }
            self.expensesWithUser = combinedData
            self.overallOwingAmount = expenseByUser
            self.setGroupViewState()
        }
    }

    private func calculateExpensesSimply() {
        guard let userId = self.preference.user?.id else { return }

        let queue = DispatchGroup()
        var ownAmounts: [String: Double] = [:]
        var combinedData: [ExpenseWithUser] = []

        overallOwingAmount = 0.0
        memberOwingAmount = [:]

        for expense in expenses {
            queue.enter()

            ownAmounts[expense.paidBy, default: 0.0] += expense.amount
            let splitAmount = expense.amount / Double(expense.splitTo.count)

            for member in expense.splitTo {
                ownAmounts[member, default: 0.0] -= splitAmount
            }

            self.fetchUserData(for: expense.paidBy) { user in
                combinedData.append(ExpenseWithUser(expense: expense, user: user))
                queue.leave()
            }
        }

        queue.notify(queue: .main) {
            let debts = self.settleDebts(users: ownAmounts)

            for debt in debts where debt.0 == userId || debt.1 == userId {
                self.overallOwingAmount += debt.1 == userId ? debt.2 : -debt.2
                self.memberOwingAmount[debt.1 == userId ? debt.0 : debt.1] = debt.1 == userId ? debt.2 : -debt.2
            }

            self.expensesWithUser = combinedData
            self.setGroupViewState()
        }
    }

    private func settleDebts(users: [String: Double]) -> [(String, String, Double)] {
        var creditors: [(String, Double)] = []
        var debtors: [(String, Double)] = []

        // Separate users into creditors and debtors
        for (user, balance) in users {
            if balance > 0 {
                creditors.append((user, balance))
            } else if balance < 0 {
                debtors.append((user, -balance)) // Store as positive for ease of calculation
            }
        }

        // Sort creditors and debtors by the amount they owe or are owed
        creditors.sort { $0.1 < $1.1 }
        debtors.sort { $0.1 < $1.1 }

        var transactions: [(String, String, Double)] = [] // (debtor, creditor, amount)
        var cIdx = 0
        var dIdx = 0

        while cIdx < creditors.count && dIdx < debtors.count { // Process all debts
            let (creditor, credAmt) = creditors[cIdx]
            let (debtor, debtAmt) = debtors[dIdx]
            let minAmt = min(credAmt, debtAmt)

            transactions.append((debtor, creditor, minAmt)) // Record the transaction

            // Update the amounts
            creditors[cIdx] = (creditor, credAmt - minAmt)
            debtors[dIdx] = (debtor, debtAmt - minAmt)

            // Move the index forward if someone's balance is settled
            if creditors[cIdx].1 == 0 { cIdx += 1 }
            if debtors[dIdx].1 == 0 { dIdx += 1 }
        }
        return transactions
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
        (expenses.isEmpty ? .noExpense : (overallOwingAmount == 0 ? .settledUp : .hasExpense)) :
        (expenses.isEmpty ? .noMember : (overallOwingAmount == 0 ? .settledUp : .hasExpense))
    }

    func showExpenseDeleteAlert(expenseId: String) {
        showAlert = true
        alert = .init(title: "Delete expense",
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
            }.store(in: &cancelable)
    }
}

// MARK: - User Actions
extension GroupHomeViewModel {
    func setHasExpenseState() {
        groupState = .loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.groupState = .hasExpense
        }
    }

    func getMemberDataBy(id: String) -> AppUser? {
        return groupUserData.first(where: { $0.id == id })
    }

    func handleCreateGroupClick() {
        router.push(.CreateGroupView(group: nil))
    }

    func handleAddMemberClick() {
        router.push(.InviteMemberView(groupId: groupId))
    }

    func handleSettingButtonTap() {
        router.push(.GroupSettingView(groupId: groupId))
    }

    func handleExpenseItemTap(expenseId: String) {
        router.push(.ExpenseDetailView(expenseId: expenseId))
    }

    func handleSettleUpBtnTap() {
        showSettleUpSheet = true
    }

    func handleBalancesBtnTap() {
        showBalancesSheet = true
    }

    func handleTotalBtnTap() {
        showGroupTotalSheet = true
    }

    func handleSearchOptionTap() {
        withAnimation {
            showSearchBar = true
        }
    }

    func onSearchBarCancelBtnTap() {
        withAnimation {
            showSearchBar = false
        }
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
            return components1.year! > components2.year!
        }
        // If years are the same, compare months
        else {
            return components1.month! > components2.month!
        }
    }
}

// MARK: - Group State
extension GroupHomeViewModel {
    enum GroupState {
        case loading
        case noMember
        case noExpense
        case settledUp
        case hasExpense
    }
}

// Struct to hold combined expense and user information
struct ExpenseWithUser {
    let expense: Expense
    let user: AppUser
}
