//
//  GroupListViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 08/03/24.
//

import Data
import Combine
import SwiftUI

class GroupListViewModel: BaseViewModel, ObservableObject {

    @Inject private var preference: SplitoPreference
    @Inject private var groupRepository: GroupRepository
    @Inject private var expenseRepository: ExpenseRepository
    @Inject private var transactionRepository: TransactionRepository

    @Published private(set) var currentViewState: ViewState = .loading
    @Published private(set) var groupListState: GroupListState = .noGroup

    @Published var searchedGroup: String = ""
    @Published private(set) var showSearchBar = false
    @Published private(set) var usersTotalExpense = 0.0

    private var groups: [Groups] = []
    private let router: Router<AppRoute>

    var filteredGroups: [GroupInformation] {
        guard case .hasGroup(let groups) = groupListState else { return [] }
        return searchedGroup.isEmpty ? groups : groups.filter { $0.group.name.localizedCaseInsensitiveContains(searchedGroup) }
    }

    init(router: Router<AppRoute>) {
        self.router = router
        super.init()
        self.fetchLatestGroups()
        self.observeLatestExpenses()
    }

    func fetchGroups() {
        guard let userId = preference.user?.id else { return }

        let groupsPublisher = groupRepository.fetchGroups(userId: userId)
        processGroupsDetails(groupsPublisher)
    }

    private func observeLatestExpenses() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.fetchLatestExpenses()
        }
    }

    private func fetchLatestExpenses() {
        guard !groups.isEmpty else { return }

        groups.forEach { group in
            guard let groupId = group.id else { return }

            expenseRepository.fetchLatestExpensesBy(groupId: groupId)
                .sink(receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.currentViewState = .initial
                        self?.showToastFor(error)
                    }
                }, receiveValue: { [weak self] _ in
                    self?.fetchLatestGroups()
                })
                .store(in: &cancelable)
        }
    }

    private func fetchLatestGroups() {
        guard let userId = preference.user?.id else { return }

        let latestGroupsPublisher = groupRepository.fetchLatestGroups(userId: userId)
        processGroupsDetails(latestGroupsPublisher)
    }

    private func processGroupsDetails(_ groupsPublisher: AnyPublisher<[Groups], ServiceError>) {
        groupsPublisher
            .flatMap { [weak self] groups -> AnyPublisher<[GroupInformation], ServiceError> in
                guard let self else {
                    self?.currentViewState = .initial
                    return Fail(error: .dataNotFound).eraseToAnyPublisher()
                }

                self.groups = groups

                let groupInfoPublishers = groups.map { group in
                    self.fetchGroupInformation(group: group)
                }

                return Publishers.MergeMany(groupInfoPublishers).collect().eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.currentViewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] groups in
                guard let self else { return }
                self.currentViewState = .initial
                let sortedGroups = groups.sorted { $0.group.name < $1.group.name }
                self.groupListState = sortedGroups.isEmpty ? .noGroup : .hasGroup(groups: sortedGroups)
                self.usersTotalExpense = groups.reduce(0.0) { $0 + $1.oweAmount }
            }
            .store(in: &cancelable)
    }

    private func fetchGroupInformation(group: Groups) -> AnyPublisher<GroupInformation, ServiceError> {
        guard let groupId = group.id else {
            return Fail(error: ServiceError.dataNotFound).eraseToAnyPublisher()
        }

        return fetchExpenses(group: group)
            .combineLatest(fetchGroupMembers(groupId: groupId))
            .map { (expenseTuple, members) -> GroupInformation in
                let (expense, owingAmounts, hasExpenses) = expenseTuple
                return GroupInformation(group: group, oweAmount: expense, memberOweAmount: owingAmounts, members: members, hasExpenses: hasExpenses)
            }
            .eraseToAnyPublisher()
    }

    private func fetchGroupMembers(groupId: String) -> AnyPublisher<[AppUser], ServiceError> {
        groupRepository.fetchMembersBy(groupId: groupId)
    }

    private func fetchExpenses(group: Groups) -> AnyPublisher<(Double, [String: Double], Bool), ServiceError> {
        guard let groupId = group.id else {
            return Fail(error: ServiceError.dataNotFound).eraseToAnyPublisher()
        }

        let expensesPublisher = expenseRepository.fetchExpensesBy(groupId: groupId)
        let transactionsPublisher = transactionRepository.fetchTransactionsBy(groupId: groupId)
            .mapError { _ in ServiceError.dataNotFound }
            .catch { _ in Just([]).setFailureType(to: ServiceError.self) }

        return expensesPublisher
            .combineLatest(transactionsPublisher)
            .flatMap { [weak self] (expenses, transactions) -> AnyPublisher<(Double, [String: Double], Bool), ServiceError> in
                guard let self else { return Fail(error: ServiceError.dataNotFound).eraseToAnyPublisher() }

                let expensesPublisher: AnyPublisher<(Double, [String: Double]), ServiceError>

                if group.isDebtSimplified {
                    expensesPublisher = self.calculateExpensesSimply(expenses: expenses, transactions: transactions)
                } else {
                    expensesPublisher = self.calculateExpenses(expenses: expenses, transactions: transactions)
                }

                return expensesPublisher
                    .map { (total, owingAmounts) in
                        return (total, owingAmounts, !expenses.isEmpty)
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    private func calculateExpenses(expenses: [Expense], transactions: [Transactions]) -> AnyPublisher<(Double, [String: Double]), ServiceError> {
        guard let userId = self.preference.user?.id else { return Fail(error: .dataNotFound).eraseToAnyPublisher() }

        var expenseByUser = 0.0
        var owesToUser: [String: Double] = [:]
        var owedByUser: [String: Double] = [:]
        var ownAmount: [String: Double] = [:]

        for expense in expenses {
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
        }

        for transaction in transactions {
            let payer = transaction.payerId
            let receiver = transaction.receiverId
            let amount = transaction.amount

            if transaction.payerId == userId {
                if owedByUser[receiver] != nil {
                    owesToUser[transaction.receiverId, default: 0.0] += amount
                } else {
                    owedByUser[transaction.payerId, default: 0.0] -= amount
                }
            } else if transaction.receiverId == userId {
                if owesToUser[payer] != nil {
                    owedByUser[transaction.payerId, default: 0.0] += amount
                } else {
                    owesToUser[payer] = -amount
                }
            }
        }

        owesToUser.forEach { userId, owesAmount in
            ownAmount[userId] = owesAmount
        }
        owedByUser.forEach { userId, owedAmount in
            ownAmount[userId] = (ownAmount[userId] ?? 0) - owedAmount
        }
        expenseByUser = ownAmount.values.reduce(0, +)

        return Just((expenseByUser, ownAmount)).setFailureType(to: ServiceError.self).eraseToAnyPublisher()
    }

    private func calculateExpensesSimply(expenses: [Expense], transactions: [Transactions]) -> AnyPublisher<(Double, [String: Double]), ServiceError> {
        guard let userId = self.preference.user?.id else { return Fail(error: .dataNotFound).eraseToAnyPublisher() }

        var expenseByUser = 0.0
        var ownAmount: [String: Double] = [:]

        for expense in expenses {
            ownAmount[expense.paidBy, default: 0.0] += expense.amount
            let splitAmount = expense.amount / Double(expense.splitTo.count)

            for member in expense.splitTo {
                ownAmount[member, default: 0.0] -= splitAmount
            }
        }

        var oweByUser: [String: Double] = [:]
        let debts = settleDebts(users: ownAmount)

        for debt in debts where debt.0 == userId || debt.1 == userId {
            expenseByUser += debt.1 == userId ? debt.2 : -debt.2
            oweByUser[debt.1 == userId ? debt.0 : debt.1] = debt.1 == userId ? debt.2 : -debt.2
        }

        for transaction in transactions {
            let payer = transaction.payerId
            let receiver = transaction.receiverId
            let amount = transaction.amount

            if payer == userId, let currentAmount = oweByUser[receiver] {
                oweByUser[receiver] = currentAmount + amount
            } else if receiver == userId, let currentAmount = oweByUser[payer] {
                oweByUser[payer] = currentAmount - amount
            }
        }

        expenseByUser = oweByUser.values.reduce(0, +)

        return Just((expenseByUser, oweByUser)).setFailureType(to: ServiceError.self).eraseToAnyPublisher()
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
}

// MARK: - User Actions

extension GroupListViewModel {
    func getMemberData(from members: [AppUser], of id: String) -> AppUser? {
        return members.first(where: { $0.id == id })
    }

    func handleCreateGroupBtnTap() {
        router.push(.CreateGroupView(group: nil))
    }

    func handleJoinGroupBtnTap() {
        router.push(.JoinMemberView)
    }

    func handleGroupItemTap(_ group: Groups) {
        onSearchBarCancelBtnTap()
        if let id = group.id {
            router.push(.GroupHomeView(groupId: id))
        }
    }

    func handleSearchBarTap() {
        withAnimation {
            searchedGroup = ""
            showSearchBar.toggle()
        }
    }

    func onSearchBarCancelBtnTap() {
        withAnimation {
            searchedGroup = ""
            showSearchBar = false
        }
    }
}

// MARK: - To show group and expense together
struct GroupInformation {
    let group: Groups
    let oweAmount: Double
    let memberOweAmount: [String: Double]
    let members: [AppUser]
    let hasExpenses: Bool
}

// MARK: - Group States
extension GroupListViewModel {

    enum ViewState {
        case initial
        case loading
    }

    enum GroupListState: Equatable {
        static func == (lhs: GroupListViewModel.GroupListState, rhs: GroupListViewModel.GroupListState) -> Bool {
            lhs.key == rhs.key
        }

        case noGroup
        case hasGroup(groups: [GroupInformation])

        var key: String {
            switch self {
            case .noGroup:
                "noGroup"
            case .hasGroup:
                "hasGroup"
            }
        }
    }
}
