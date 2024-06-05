//
//  GroupSettleUpViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 03/06/24.
//

import Data
import Combine
import SwiftUI

class GroupSettleUpViewModel: BaseViewModel, ObservableObject {

    @Inject var preference: SplitoPreference
    @Inject var groupRepository: GroupRepository
    @Inject var expenseRepository: ExpenseRepository

    @Published var group: Groups?
    @Published var members: [AppUser] = []
    @Published var viewState: ViewState = .initial

    @Published private var expenses: [Expense] = []
    @Published var memberOwingAmount: [String: Double] = [:]

    private let groupId: String
    private var groupMemberData: [AppUser] = []
    private let router: Router<AppRoute>?

    init(router: Router<AppRoute>? = nil, groupId: String) {
        self.router = router
        self.groupId = groupId
        super.init()
        fetchGroupDetails()
    }

    // MARK: - Data Loading
    func fetchGroupDetails() {
        groupRepository.fetchGroupBy(id: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] group in
                guard let self, let group else { return }
                self.group = group
                self.fetchGroupMembers()
            }.store(in: &cancelable)
    }

    private func fetchGroupMembers() {
        guard let user = preference.user else { return }

        groupRepository.fetchMembersBy(groupId: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] members in
                guard let self else { return }
                self.members = members
                self.members.removeAll(where: { $0.id == user.id })
                self.fetchExpenses()
            }.store(in: &cancelable)
    }

    private func fetchExpenses() {
        expenseRepository.fetchExpensesBy(groupId: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
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

        var owesToUser: [String: Double] = [:]
        var owedByUser: [String: Double] = [:]

        memberOwingAmount = [:]

        for expense in expenses {
            let splitAmount = expense.amount / Double(expense.splitTo.count)

            if expense.paidBy == userId {
                for member in expense.splitTo where member != userId {
                    owesToUser[member, default: 0.0] += splitAmount
                }
            } else if expense.splitTo.contains(where: { $0 == userId }) {
                owedByUser[expense.paidBy, default: 0.0] += splitAmount
            }
        }

        DispatchQueue.main.async {
            owesToUser.forEach { userId, owesAmount in
                self.memberOwingAmount[userId] = owesAmount
            }
            owedByUser.forEach { userId, owedAmount in
                self.memberOwingAmount[userId] = (self.memberOwingAmount[userId] ?? 0) - owedAmount
            }
        }
    }

    private func calculateExpensesSimply() {
        guard let userId = self.preference.user?.id else { return }

        var ownAmounts: [String: Double] = [:]

        memberOwingAmount = [:]

        for expense in expenses {
            ownAmounts[expense.paidBy, default: 0.0] += expense.amount
            let splitAmount = expense.amount / Double(expense.splitTo.count)

            for member in expense.splitTo {
                ownAmounts[member, default: 0.0] -= splitAmount
            }
        }

        DispatchQueue.main.async {
            let debts = self.settleDebts(users: ownAmounts)
            for debt in debts where debt.0 == userId || debt.1 == userId {
                self.memberOwingAmount[debt.1 == userId ? debt.0 : debt.1] = debt.1 == userId ? debt.2 : -debt.2
            }
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

    func getMemberDataBy(id: String) -> AppUser? {
        return members.first(where: { $0.id == id })
    }

    func handleMoreButtonTap() {
        router?.push(.GroupWhoIsPayingView(groupId: groupId))
    }

    func onMemberTap(memberId: String, amount: Double) {
        guard let userId = self.preference.user?.id else { return }

        let payerUserId = amount < 0 ? userId : memberId
        let payableUserId = amount < 0 ? memberId : userId
        router?.push(.GroupPaymentView(groupId: groupId, payerUserId: payerUserId, payableUserId: payableUserId, amount: amount))
    }

    // MARK: - Error Handling
    private func handleServiceError(_ error: ServiceError) {
        viewState = .initial
        showToastFor(error)
    }
}

// MARK: - View States
extension GroupSettleUpViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
