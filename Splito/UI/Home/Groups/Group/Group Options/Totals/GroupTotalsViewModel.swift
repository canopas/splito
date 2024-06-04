//
//  GroupTotalsViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 04/06/24.
//

import Data
import Combine
import SwiftUI

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

class GroupTotalsViewModel: BaseViewModel, ObservableObject {

    @Inject var preference: SplitoPreference
    @Inject var groupRepository: GroupRepository
    @Inject var expenseRepository: ExpenseRepository

    @Published var viewState: ViewState = .initial
    @Published var selectedTab: GroupTotalsTabType = .thisMonth

    @Published var group: Groups?
    @Published private var expenses: [Expense] = []
    @Published var filteredExpenses: [Expense] = []

    private let groupId: String

    init(groupId: String) {
        self.groupId = groupId
        super.init()
        self.fetchGroupAndExpenses()
    }

    private func fetchGroupAndExpenses() {
        viewState = .loading
        groupRepository.fetchGroupBy(id: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.viewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] group in
                guard let self, let group else { return }
                self.group = group
                self.fetchExpenses(group: group)
            }.store(in: &cancelable)
    }

    private func fetchExpenses(group: Groups) {
        expenseRepository.fetchExpensesBy(groupId: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.viewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] expenses in
                guard let self else { return }
                self.expenses = expenses
                self.filteredExpensesForSelectedTab()
                self.viewState = .initial
            }.store(in: &cancelable)
    }

    func handleTabItemSelection(_ selection: GroupTotalsTabType) {
        withAnimation(.easeInOut(duration: 0.3), {
            selectedTab = selection
            filteredExpensesForSelectedTab()
        })
    }

    private func filteredExpensesForSelectedTab() {
        switch selectedTab {
        case .thisMonth:
            let calendar = Calendar.current
            let currentMonth = calendar.component(.month, from: Date())
            let currentYear = calendar.component(.year, from: Date())

            filteredExpenses = expenses.filter {
                let expenseDate = $0.date.dateValue()
                let expenseMonth = calendar.component(.month, from: expenseDate)
                let expenseYear = calendar.component(.year, from: expenseDate)
                return expenseMonth == currentMonth && expenseYear == currentYear
            }
        case .lastMonth:
            let calendar = Calendar.current
            let currentDate = Date()

            guard let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: currentDate) else {
                return
            }

            let lastMonth = calendar.component(.month, from: lastMonthDate)
            let lastMonthYear = calendar.component(.year, from: lastMonthDate)

            filteredExpenses = expenses.filter {
                let expenseDate = $0.date.dateValue()
                let expenseMonth = calendar.component(.month, from: expenseDate)
                let expenseYear = calendar.component(.year, from: expenseDate)
                return expenseMonth == lastMonth && expenseYear == lastMonthYear
            }
        case .allTime:
            filteredExpenses = expenses
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
        let userExpenses = filteredExpenses.filter { $0.paidBy == user.id }
        return userExpenses.reduce(0) { $0 + $1.amount }
    }

    func getTotalChangeInBalance() -> Double {
        guard let user = preference.user else { return 0 }

        var amountOweByMember: [String: Double] = [:]

        for expense in filteredExpenses {
            amountOweByMember[expense.paidBy, default: 0.0] += expense.amount

            let splitAmount = expense.amount / Double(expense.splitTo.count)
            for member in expense.splitTo {
                amountOweByMember[member, default: 0.0] -= splitAmount
            }
        }
        return amountOweByMember[user.id] ?? 0
    }
}

// MARK: - View States
extension GroupTotalsViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
