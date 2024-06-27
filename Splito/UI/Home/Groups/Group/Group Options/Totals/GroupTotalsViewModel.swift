//
//  GroupTotalsViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 04/06/24.
//

import Data
import SwiftUI

class GroupTotalsViewModel: BaseViewModel, ObservableObject {

    @Inject private var preference: SplitoPreference
    @Inject private var groupRepository: GroupRepository
    @Inject private var expenseRepository: ExpenseRepository
    @Inject private var transactionRepository: TransactionRepository

    @Published private(set) var viewState: ViewState = .initial
    @Published private(set) var selectedTab: GroupTotalsTabType = .thisMonth

    @Published private(set) var group: Groups?
    @Published private(set) var filteredExpenses: [Expense] = []

    private let groupId: String
    private var expenses: [Expense] = []
    private var transactions: [Transactions] = []
    private var filteredTransactions: [Transactions] = []

    init(groupId: String) {
        self.groupId = groupId
        super.init()
        self.fetchGroupAndExpenses()
    }

    // MARK: - Data Loading
    private func fetchGroupAndExpenses() {
        viewState = .loading
        groupRepository.fetchGroupBy(id: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] group in
                guard let self, let group else { return }
                self.group = group
                self.fetchTransactions()
                self.fetchExpenses(group: group)
                self.viewState = .initial
            }.store(in: &cancelable)
    }

    private func fetchExpenses(group: Groups) {
        expenseRepository.fetchExpensesBy(groupId: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] expenses in
                guard let self else { return }
                self.expenses = expenses
                self.filteredExpensesForSelectedTab()
            }.store(in: &cancelable)
    }

    private func fetchTransactions() {
        transactionRepository.fetchTransactionsBy(groupId: groupId).sink { [weak self] completion in
            if case .failure(let error) = completion {
                self?.handleServiceError(error)
            }
        } receiveValue: { [weak self] transactions in
            guard let self else { return }
            self.transactions = transactions
            self.filteredTransactionsForSelectedTab()
        }.store(in: &cancelable)
    }

    // MARK: - User Actions
    func handleTabItemSelection(_ selection: GroupTotalsTabType) {
        withAnimation(.easeInOut(duration: 0.3), {
            selectedTab = selection
            filteredExpensesForSelectedTab()
            filteredTransactionsForSelectedTab()
        })
    }

    private func filteredExpensesForSelectedTab() {
        filteredExpenses = filterItemsForSelectedTab(
            items: expenses,
            dateExtractor: { $0.date.dateValue() },
            for: selectedTab
        )
    }

    private func filteredTransactionsForSelectedTab() {
        filteredTransactions = filterItemsForSelectedTab(
            items: transactions,
            dateExtractor: { $0.date.dateValue() },
            for: selectedTab
        )
    }

    private func filterItemsForSelectedTab<T>(items: [T], dateExtractor: (T) -> Date, for tab: GroupTotalsTabType) -> [T] {
        let calendar = Calendar.current

        switch tab {
        case .thisMonth:
            let currentMonth = calendar.component(.month, from: Date())
            let currentYear = calendar.component(.year, from: Date())

            return items.filter {
                let itemDate = dateExtractor($0)
                let itemMonth = calendar.component(.month, from: itemDate)
                let itemYear = calendar.component(.year, from: itemDate)
                return itemMonth == currentMonth && itemYear == currentYear
            }
        case .lastMonth:
            let currentDate = Date()
            guard let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: currentDate) else {
                return []
            }

            let lastMonth = calendar.component(.month, from: lastMonthDate)
            let lastMonthYear = calendar.component(.year, from: lastMonthDate)

            return items.filter {
                let itemDate = dateExtractor($0)
                let itemMonth = calendar.component(.month, from: itemDate)
                let itemYear = calendar.component(.year, from: itemDate)
                return itemMonth == lastMonth && itemYear == lastMonthYear
            }
        case .allTime:
            return items
        }
    }

    func getTotalShareAmount() -> Double {
        guard let user = preference.user else { return 0 }

        let userSharedExpenses = filteredExpenses.filter { $0.splitTo.contains(user.id) }

        let totalSharedAmount = userSharedExpenses.reduce(0.0) { total, expense in
            var share = 0.0
            switch expense.splitType {
            case .equally:
                share = expense.amount / Double(expense.splitTo.count)
            case .percentage:
                let userPercentage: Double = 1.0 / Double(expense.splitTo.count)
                share = expense.amount * userPercentage
            case .fixedAmount:
                let userFixedAmount: Double = expense.amount / Double(expense.splitTo.count)
                share = userFixedAmount
            }
            return total + share
        }
        return totalSharedAmount
    }

    func getTotalPaid() -> Double {
        guard let user = preference.user else { return 0 }
        return filteredExpenses.filter { $0.paidBy == user.id }.reduce(0) { $0 + $1.amount }
    }

    func getPaymentsMade() -> Double {
        guard let user = preference.user else { return 0 }
        return filteredTransactions.filter { $0.payerId == user.id }.reduce(0) { $0 + $1.amount }
    }

    func getPaymentsReceived() -> Double {
        guard let user = preference.user else { return 0 }
        return filteredTransactions.filter { $0.receiverId == user.id }.reduce(0) { $0 + $1.amount }
    }

    func getTotalChangeInBalance() -> Double {
        guard let user = preference.user else { return 0 }

        let amountOweByMember = calculateTransactionsWithExpenses(expenses: filteredExpenses, transactions: filteredTransactions)
        return amountOweByMember[user.id] ?? 0
    }

    // MARK: - Error Handling
    private func handleServiceError(_ error: ServiceError) {
        viewState = .initial
        showToastFor(error)
    }
}

// MARK: - View States
extension GroupTotalsViewModel {
    enum ViewState {
        case initial
        case loading
    }
}

// MARK: - Tab Types
enum GroupTotalsTabType: Int, CaseIterable {

    case thisMonth, lastMonth, allTime

    var tabItem: String {
        switch self {
        case .thisMonth:
            return "This month"
        case .lastMonth:
            return "Last month"
        case .allTime:
            return "All time"
        }
    }
}
