//
//  GroupListViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 08/03/24.
//

import Data
import Combine
import Foundation

class GroupListViewModel: BaseViewModel, ObservableObject {

    @Inject var preference: SplitoPreference
    @Inject var groupRepository: GroupRepository
    @Inject var expenseRepository: ExpenseRepository

	@Published var groups: [Groups] = []
    @Published var currentViewState: ViewState = .loading
    @Published var groupListState: GroupListState = .noGroup

    @Published var showGroupMenu = false
    @Published var usersTotalExpense = 0.0

    private let router: Router<AppRoute>

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

    func fetchLatestExpenses() {
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

    func fetchLatestGroups() {
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

        return fetchGroupMembers(groupId: groupId)
            .combineLatest(fetchExpenses(group: group))
            .map { (members, amountTuple) in
                let (expense, owingAmounts) = amountTuple
                return GroupInformation(group: group, oweAmount: expense, memberOweAmount: owingAmounts, members: members)
            }
            .eraseToAnyPublisher()
    }

    private func fetchGroupMembers(groupId: String) -> AnyPublisher<[AppUser], ServiceError> {
        groupRepository.fetchMembersBy(groupId: groupId)
    }

    private func fetchExpenses(group: Groups) -> AnyPublisher<(Double, [String: Double]), ServiceError> {
        expenseRepository.fetchExpensesBy(groupId: group.id ?? "")
            .flatMap { [weak self] expenses -> AnyPublisher<(Double, [String: Double]), ServiceError> in
                guard let self else { return Fail(error: .dataNotFound).eraseToAnyPublisher() }
                if group.isDebtSimplified {
                    return self.calculateExpensesSimply(expenses: expenses)
                } else {
                    return self.calculateExpenses(expenses: expenses)
                }
            }
            .eraseToAnyPublisher()
    }

    private func calculateExpenses(expenses: [Expense]) -> AnyPublisher<(Double, [String: Double]), ServiceError> {
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

        owesToUser.forEach { userId, owesAmount in
            ownAmount[userId] = owesAmount
        }
        owedByUser.forEach { userId, owedAmount in
            ownAmount[userId] = (ownAmount[userId] ?? 0) - owedAmount
        }
        return Just((expenseByUser, ownAmount)).setFailureType(to: ServiceError.self).eraseToAnyPublisher()
    }

    private func calculateExpensesSimply(expenses: [Expense]) -> AnyPublisher<(Double, [String: Double]), ServiceError> {
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
        return Just((expenseByUser, oweByUser)).setFailureType(to: ServiceError.self).eraseToAnyPublisher()
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
        if let id = group.id {
            router.push(.GroupHomeView(groupId: id))
        }
    }
}

// MARK: - To show group and expense together
struct GroupInformation {
    let group: Groups
    let oweAmount: Double
    let memberOweAmount: [String: Double]
    let members: [AppUser]
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
