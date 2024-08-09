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
    @Published private(set) var selectedTab: GroupListTabType = .all

    @Published var searchedGroup: String = ""
    @Published var selectedGroup: Groups?
    @Published private(set) var usersTotalExpense = 0.0

    @Published var showActionSheet = false
    @Published private(set) var showSearchBar = false
    @Published private(set) var showScrollToTopBtn = false
    @Published var showCreateGroupSheet = false
    @Published var showJoinGroupSheet = false

    private var groups: [Groups] = []
    let router: Router<AppRoute>

    var filteredGroups: [GroupInformation] {
        guard case .hasGroup(let groups) = groupListState else { return [] }

        switch selectedTab {
        case .all:
            return searchedGroup.isEmpty ? groups : groups.filter { $0.group.name.localizedCaseInsensitiveContains(searchedGroup) }
        case .settled:
            return searchedGroup.isEmpty ? groups.filter { $0.oweAmount == 0 } : groups.filter { $0.oweAmount == 0 &&
                $0.group.name.localizedCaseInsensitiveContains(searchedGroup) }
        case .unsettled:
            return searchedGroup.isEmpty ? groups.filter { $0.oweAmount != 0 } : groups.filter { $0.oweAmount != 0 &&
                $0.group.name.localizedCaseInsensitiveContains(searchedGroup) }
        }
    }

    init(router: Router<AppRoute>) {
        self.router = router
        super.init()
        self.fetchLatestGroups()
        self.observeLatestExpenses()
    }

    // MARK: - Data Loading
    func fetchGroups() {
        guard let userId = preference.user?.id else { return }

        let groupsPublisher = groupRepository.fetchGroups(userId: userId)
        processGroupsDetails(groupsPublisher)
    }

    private func observeLatestExpenses() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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

        return expensesPublisher
            .combineLatest(transactionsPublisher)
            .flatMap { [weak self] (expenses, transactions) -> AnyPublisher<(Double, [String: Double], Bool), ServiceError> in
                guard let self else { return Fail(error: ServiceError.dataNotFound).eraseToAnyPublisher() }

                let expensesPublisher: AnyPublisher<(Double, [String: Double]), ServiceError>

                if group.isDebtSimplified {
                    expensesPublisher = self.calculateExpenses(members: group.members, expenses: expenses, transactions: transactions)
                } else {
                    expensesPublisher = self.calculateExpenses(members: group.members, expenses: expenses, transactions: transactions)
                }

                return expensesPublisher
                    .map { (total, owingAmounts) in
                        return (total, owingAmounts, !expenses.isEmpty)
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    private func calculateExpenses(members: [String], expenses: [Expense], transactions: [Transactions]) -> AnyPublisher<(Double, [String: Double]), ServiceError> {
        guard let userId = self.preference.user?.id else { return Fail(error: .dataNotFound).eraseToAnyPublisher() }

        let memberOwingAmount = calculateExpensesSimplified(userId: userId, members: members, expenses: expenses, transactions: transactions)
        return Just((memberOwingAmount.values.reduce(0, +), memberOwingAmount)).setFailureType(to: ServiceError.self).eraseToAnyPublisher()
    }
}

// MARK: - User Actions

extension GroupListViewModel {
    func getMemberData(from members: [AppUser], of id: String) -> AppUser? {
        return members.first(where: { $0.id == id })
    }

    func handleCreateGroupBtnTap() {
        showCreateGroupSheet = true
    }

    func handleJoinGroupBtnTap() {
        showJoinGroupSheet = true
    }

    func handleGroupItemTap(_ group: Groups, isTapped: Bool = true) {
        if isTapped {
            onSearchBarCancelBtnTap()
            if let id = group.id {
                router.push(.GroupHomeView(groupId: id))
            }
        } else {
            handleGroupItemLongPress(group)
        }
    }

    func handleSearchBarTap() {
        if filteredGroups.isEmpty {
            showToastFor(toast: .init(type: .info, title: "No groups yet", message: "There are no groups available to search."))
        } else {
            withAnimation {
                searchedGroup = ""
                showSearchBar.toggle()
            }
        }
    }

    func onSearchBarCancelBtnTap() {
        if showSearchBar {
            withAnimation {
                searchedGroup = ""
                showSearchBar = false
            }
        }
    }

    func handleTabItemSelection(_ selection: GroupListTabType) {
        guard case .hasGroup(let groups) = groupListState else { return }
        let settledGroups = groups.filter { $0.oweAmount == 0 }
        let unsettledGroups = groups.filter { $0.oweAmount != 0 }

        withAnimation(.easeInOut(duration: 0.3)) {
            selectedTab = selection
            if (selection == .settled && settledGroups.isEmpty || selection == .unsettled && unsettledGroups.isEmpty) && showSearchBar {
                onSearchBarCancelBtnTap()
            }
        }
    }

    func manageScrollToTopBtnVisibility(offset: CGFloat) {
        showScrollToTopBtn = offset < 0
    }

    func handleGroupItemLongPress(_ group: Groups) {
        selectedGroup = group
        showActionSheet = true
    }

    func handleOptionSelection(with selection: OptionList) {
        showActionSheet = false
        guard let group = selectedGroup else { return }

        switch selection {
        case .editGroup:
            router.push(.CreateGroupView(group: group))
        case .deleteGroup:
            handleDeleteGroupTap(groupId: group.id)
        }
    }

    func handleDeleteGroupTap(groupId: String?) {
        alert = .init(title: "Delete Group",
                      message: "Are you ABSOLUTELY sure you want to delete this group? This will remove this group for ALL users involved, not just yourself.",
                      positiveBtnTitle: "Delete",
                      positiveBtnAction: { self.deleteGroup(groupId: groupId) },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false }, isPositiveBtnDestructive: true)
        showAlert = true
    }

    private func deleteGroup(groupId: String?) {
        guard let groupId else { return }

        groupRepository.deleteGroup(groupID: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.showToastFor(error)
                }
            } receiveValue: { _ in
            }.store(in: &cancelable)
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

// MARK: - Tab Types
enum GroupListTabType: Int, CaseIterable {

    case all, settled, unsettled

    var tabItem: String {
        switch self {
        case .all:
            return "All"
        case .settled:
            return "Settled"
        case .unsettled:
            return "Unsettled"
        }
    }
}

enum OptionList: CaseIterable {
    case editGroup
    case deleteGroup

    var title: String {
        switch self {
        case .editGroup:
            return "Edit group"
        case .deleteGroup:
            return "Delete group"
        }
    }

    var image: ImageResource {
        switch self {
        case .editGroup:
            return .editPencilIcon
        case .deleteGroup:
            return .binIcon
        }
    }
}
