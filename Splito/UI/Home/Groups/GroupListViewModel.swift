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

        let memberOwingAmount = calculateExpensesNonSimplify(userId: userId, expenses: expenses, transactions: transactions)

        return Just((memberOwingAmount.values.reduce(0, +), memberOwingAmount)).setFailureType(to: ServiceError.self).eraseToAnyPublisher()
    }

    private func calculateExpensesSimply(expenses: [Expense], transactions: [Transactions]) -> AnyPublisher<(Double, [String: Double]), ServiceError> {
        guard let userId = self.preference.user?.id else { return Fail(error: .dataNotFound).eraseToAnyPublisher() }

        let oweByUser = calculateExpensesSimplify(userId: userId, expenses: expenses, transactions: transactions)

        return Just((oweByUser.values.reduce(0, +), oweByUser)).setFailureType(to: ServiceError.self).eraseToAnyPublisher()
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
