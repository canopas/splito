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
    private func fetchGroupDetails() {
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
                guard let self, let group, let userId = preference.user?.id else { return }
                self.expenses = expenses
                memberOwingAmount = [:]
                if group.isDebtSimplified {
                    self.memberOwingAmount = calculateExpensesSimplify(userId: userId, expenses: expenses, transactions: transactions)
                } else {
                    self.memberOwingAmount = calculateExpensesNonSimplify(userId: userId, expenses: expenses, transactions: transactions)
                }
            }.store(in: &cancelable)
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
