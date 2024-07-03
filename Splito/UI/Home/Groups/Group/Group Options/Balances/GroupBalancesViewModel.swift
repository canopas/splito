//
//  GroupBalancesViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 26/04/24.
//

import Data
import Foundation

class GroupBalancesViewModel: BaseViewModel, ObservableObject {

    @Inject private var preference: SplitoPreference
    @Inject private var groupRepository: GroupRepository
    @Inject private var expenseRepository: ExpenseRepository
    @Inject private var transactionRepository: TransactionRepository

    @Published var viewState: ViewState = .initial
    @Published var memberBalances: [GroupMemberBalance] = []
    @Published var memberOwingAmount: [String: Double] = [:]

    private let groupId: String
    private var groupMemberData: [AppUser] = []
    private var transactions: [Transactions] = []

    init(groupId: String) {
        self.groupId = groupId
        super.init()
        fetchGroupMembers()
    }

    func fetchGroupMembers() {
        viewState = .loading
        groupRepository.fetchMembersBy(groupId: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.viewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { users in
                self.groupMemberData = users
                self.fetchGroupAndExpenses()
            }.store(in: &cancelable)
    }

    private func fetchGroupAndExpenses() {
        groupRepository.fetchGroupBy(id: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.viewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] group in
                guard let self, let group else { return }
                self.fetchTransactions()
                self.fetchExpenses(group: group)
            }.store(in: &cancelable)
    }

    private func fetchTransactions() {
        transactionRepository.fetchTransactionsBy(groupId: groupId).sink { [weak self] completion in
            if case .failure(let error) = completion {
                self?.showToastFor(error)
            }
        } receiveValue: { [weak self] transactions in
            self?.transactions = transactions
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
                calculateExpenses(expenses: expenses, isSimplify: group.isDebtSimplified)
            }.store(in: &cancelable)
    }

    private func calculateExpenses(expenses: [Expense], isSimplify: Bool) {
        let groupMembers = Array(Set(groupMemberData.map { $0.id }))
        var memberBalances = groupMembers.map { GroupMemberBalance(id: $0) }

        for expense in expenses {
            let splitAmounts = calculateSplitAmount(expense: expense)

            if let paidByIndex = memberBalances.firstIndex(where: { $0.id == expense.paidBy }) {
                memberBalances[paidByIndex].totalOwedAmount += expense.amount

                for (member, splitAmount) in splitAmounts {
                    if let owedMemberIndex = memberBalances.firstIndex(where: { $0.id == member }) {
                        memberBalances[owedMemberIndex].totalOwedAmount -= splitAmount

                        if !isSimplify && member != expense.paidBy {
                            memberBalances[owedMemberIndex].balances[expense.paidBy, default: 0.0] -= splitAmount
                            memberBalances[paidByIndex].balances[member, default: 0.0] += splitAmount
                        }
                    }
                }
            }
        }

        memberBalances = processTransactions(transactions: transactions, memberBalances: memberBalances, isSimplify: isSimplify)

        DispatchQueue.main.async { [self] in
            sortMemberBalances(memberBalances: isSimplify ? settleDebts(balances: memberBalances) : memberBalances)
        }
    }

    private func calculateSplitAmount(expense: Expense) -> [String: Double] {
        var splitAmounts: [String: Double] = [:]

        switch expense.splitType {
        case .equally:
            let splitAmount = expense.amount / Double(expense.splitTo.count)
            for member in expense.splitTo {
                splitAmounts[member] = splitAmount
            }
        case .percentage:
            if let splitData = expense.splitData {
                let totalPercentage = splitData.values.reduce(0, +)
                for (member, percentage) in splitData {
                    splitAmounts[member] = expense.amount * (percentage / totalPercentage)
                }
            }
        case .shares:
            if let splitData = expense.splitData {
                let totalShares = splitData.values.reduce(0, +)
                for (member, shares) in splitData {
                    splitAmounts[member] = expense.amount * (Double(shares) / Double(totalShares))
                }
            }
        }

        return splitAmounts
    }

    private func processTransactions(transactions: [Transactions], memberBalances: [GroupMemberBalance], isSimplify: Bool) -> [GroupMemberBalance] {
        var memberBalances: [GroupMemberBalance] = memberBalances

        for transaction in transactions {
            if let payerIndex = memberBalances.firstIndex(where: { $0.id == transaction.payerId }),
               let receiverIndex = memberBalances.firstIndex(where: { $0.id == transaction.receiverId }) {
                memberBalances[payerIndex].totalOwedAmount += transaction.amount
                memberBalances[receiverIndex].totalOwedAmount -= transaction.amount

                if !(isSimplify) {
                    memberBalances[payerIndex].balances[transaction.receiverId, default: 0.0] += transaction.amount
                    memberBalances[receiverIndex].balances[transaction.payerId, default: 0.0] -= transaction.amount
                }
            }
        }

        return memberBalances
    }

    private func settleDebts(balances: [GroupMemberBalance]) -> [GroupMemberBalance] {
        var creditors: [(GroupMemberBalance, Double)] = []
        var debtors: [(GroupMemberBalance, Double)] = []

        // Separate users into creditors and debtors
        for balance in balances {
            if balance.totalOwedAmount > 0 {
                creditors.append((balance, balance.totalOwedAmount))
            } else if balance.totalOwedAmount < 0 {
                debtors.append((balance, -balance.totalOwedAmount)) // Store as positive for ease of calculation
            }
        }

        // Sort creditors and debtors by the amount they owe or are owed
        creditors.sort { $0.1 < $1.1 }
        debtors.sort { $0.1 < $1.1 }

        var updatedBalances = balances

        while !creditors.isEmpty && !debtors.isEmpty { // Process all debts
            let (creditor, credAmt) = creditors.removeFirst()
            let (debtor, debtAmt) = debtors.removeFirst()
            let minAmt = min(credAmt, debtAmt)

            // Update the balances
            if let creditorIndex = updatedBalances.firstIndex(where: { $0.id == creditor.id }) {
                updatedBalances[creditorIndex].balances[debtor.id, default: 0.0] += minAmt
            }

            if let debtorIndex = updatedBalances.firstIndex(where: { $0.id == debtor.id }) {
                updatedBalances[debtorIndex].balances[creditor.id, default: 0.0] -= minAmt
            }

            // Reinsert any remaining balances
            if credAmt > debtAmt {
                creditors.insert((creditor, credAmt - debtAmt), at: 0)
            } else if debtAmt > credAmt {
                debtors.insert((debtor, debtAmt - credAmt), at: 0)
            }
        }
        return updatedBalances
    }

    private func sortMemberBalances(memberBalances: [GroupMemberBalance]) {
        guard let userId = preference.user?.id, let userIndex = memberBalances.firstIndex(where: { $0.id == userId }) else { return }

        var sortedMembers = memberBalances

        var userBalance = sortedMembers.remove(at: userIndex)
        userBalance.isExpanded = true
        sortedMembers.insert(userBalance, at: 0)

        sortedMembers.sort { member1, member2 in
            if member1.id == userId { true } else if member2.id == userId { false } else { getMemberName(id: member1.id) < getMemberName(id: member2.id) }
        }

        self.memberBalances = sortedMembers
        self.viewState = .initial
    }

    private func getMemberDataBy(id: String) -> AppUser? {
        return groupMemberData.first(where: { $0.id == id })
    }

    func getMemberImage(id: String) -> String {
        guard let member = getMemberDataBy(id: id) else { return "" }
        return member.imageUrl ?? ""
    }

    func getMemberName(id: String, needFullName: Bool = false) -> String {
        guard let member = getMemberDataBy(id: id) else { return "" }
        return needFullName ? member.fullName : member.nameWithLastInitial
    }

    func handleBalanceExpandView(id: String) {
        if let index = memberBalances.firstIndex(where: { $0.id == id }) {
            memberBalances[index].isExpanded.toggle()
        }
    }
}

// MARK: - Struct to hold combined expense and user owe amount
struct GroupMemberBalance {
    let id: String
    var isExpanded: Bool = false
    var totalOwedAmount: Double = 0
    var balances: [String: Double] = [:]
}

// MARK: - View States
extension GroupBalancesViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
