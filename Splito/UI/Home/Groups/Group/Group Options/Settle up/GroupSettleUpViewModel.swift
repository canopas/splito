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

    @Inject private var preference: SplitoPreference
    @Inject private var groupRepository: GroupRepository
    @Inject private var expenseRepository: ExpenseRepository
    @Inject private var transactionRepository: TransactionRepository

    @Published private(set) var viewState: ViewState = .initial
    @Published private(set) var memberOwingAmount: [String: Double] = [:]

    private let groupId: String
    private var group: Groups?
    private var members: [AppUser] = []
    private var expenses: [Expense] = []
    private var groupMemberData: [AppUser] = []
    private var transactions: [Transactions] = []
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
                self.fetchTransactions()
                self.fetchExpenses()
            }.store(in: &cancelable)
    }

    func fetchTransactions() {
        transactionRepository.fetchTransactionsBy(groupId: groupId).sink { [weak self] completion in
            if case .failure(let error) = completion {
                self?.handleServiceError(error)
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
        guard let userId = preference.user?.id else { return }

        var ownAmounts: [String: Double] = [:]

        memberOwingAmount = [:]

        // Calculate total amounts owed and paid by each user
        for expense in expenses {
            ownAmounts[expense.paidBy, default: 0.0] += expense.amount
            let splitAmount = expense.amount / Double(expense.splitTo.count)

            for member in expense.splitTo {
                ownAmounts[member, default: 0.0] -= splitAmount
            }
        }

        let debts = settleDebts(users: ownAmounts)
        for debt in debts {
            memberOwingAmount[debt.0, default: 0.0] += debt.2
            memberOwingAmount[debt.1, default: 0.0] -= debt.2
        }
        memberOwingAmount = memberOwingAmount.filter { $0.value != 0 }

        // Adjust memberOwingAmount based on transactions
        for transaction in transactions {
            let payer = transaction.payerId
            let receiver = transaction.receiverId
            let amount = transaction.amount

            if payer == userId {
                if let currentAmount = memberOwingAmount[receiver] {
                    let newAmount = currentAmount + amount
                    memberOwingAmount[receiver] = newAmount
                } else {
                    memberOwingAmount[receiver] = amount
                }
            } else if receiver == userId {
                if let currentAmount = memberOwingAmount[payer] {
                    let newAmount = currentAmount - amount
                    memberOwingAmount[payer] = newAmount
                } else {
                    memberOwingAmount[payer] = -amount
                }
            }
        }

        // Remove zero balances from memberOwingAmount
        memberOwingAmount = memberOwingAmount.filter { $0.value != 0 }
    }

    private func calculateExpensesSimply() {
        guard let userId = preference.user?.id else { return }

        var ownAmounts: [String: Double] = [:]

        memberOwingAmount = [:]

        for expense in expenses {
            ownAmounts[expense.paidBy, default: 0.0] += expense.amount
            let splitAmount = expense.amount / Double(expense.splitTo.count)

            for member in expense.splitTo {
                ownAmounts[member, default: 0.0] -= splitAmount
            }
        }

        let debts = self.settleDebts(users: ownAmounts)
        for debt in debts where debt.0 == userId || debt.1 == userId {
            self.memberOwingAmount[debt.1 == userId ? debt.0 : debt.1] = debt.1 == userId ? debt.2 : -debt.2
        }
        self.memberOwingAmount = self.memberOwingAmount.filter { $0.value != 0 }

        // Adjust memberOwingAmount based on transactions
        for transaction in self.transactions {
            let payer = transaction.payerId
            let receiver = transaction.receiverId
            let amount = transaction.amount

            if payer == userId, let currentAmount = self.memberOwingAmount[receiver] {
                self.memberOwingAmount[receiver] = currentAmount + amount
            } else if receiver == userId, let currentAmount = self.memberOwingAmount[payer] {
                self.memberOwingAmount[payer] = currentAmount - amount
            }
        }

        // Remove zero or settled debts
        self.memberOwingAmount = self.memberOwingAmount.filter { $0.value != 0 }
    }

    private func settleDebts(users: [String: Double]) -> [(String, String, Double)] {
        var mutableUsers = users
        var debts: [(String, String, Double)] = []
        let positiveAmounts = mutableUsers.filter { $0.value > 0 }
        let negativeAmounts = mutableUsers.filter { $0.value < 0 }

        for (creditor, creditAmount) in positiveAmounts {
            var remainingCredit = creditAmount

            for (debtor, debtAmount) in negativeAmounts {
                if remainingCredit == 0 { break }
                let amountToSettle = min(remainingCredit, -debtAmount)
                if amountToSettle > 0 {
                    debts.append((debtor, creditor, amountToSettle))
                    remainingCredit -= amountToSettle
                    mutableUsers[debtor]! += amountToSettle
                    mutableUsers[creditor]! -= amountToSettle
                }
            }
        }

        return debts
    }

    func getMemberDataBy(id: String) -> AppUser? {
        return members.first(where: { $0.id == id })
    }

    // MARK: - User Actions
    func handleMoreButtonTap() {
        router?.push(.GroupWhoIsPayingView(groupId: groupId))
    }

    func onMemberTap(memberId: String, amount: Double) {
        guard let userId = self.preference.user?.id else { return }

        let (payerId, receiverId) = amount < 0 ? (userId, memberId) : (memberId, userId)
        router?.push(.GroupPaymentView(transactionId: nil, groupId: groupId, payerId: payerId, receiverId: receiverId, amount: amount))
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
