//
//  GroupListViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 08/03/24.
//

import Data
import Combine
import SwiftUI
import FirebaseFirestore

class GroupListViewModel: BaseViewModel, ObservableObject {

    private let GROUPS_LIMIT = 10

    @Inject private var preference: SplitoPreference
    @Inject private var groupRepository: GroupRepository
    @Inject private var userRepository: UserRepository

    @Published private(set) var currentViewState: ViewState = .loading
    @Published private(set) var groupListState: GroupListState = .noGroup
    @Published private(set) var selectedTab: GroupListTabType = .all

    @Published var searchedGroup: String = ""
    @Published var selectedGroup: Groups?

    @Published private var groups: [Groups] = []
    @Published private(set) var combinedGroups: [GroupInformation] = []
    @Published private(set) var totalOweAmount: Double = 0.0

    @Published var showActionSheet = false
    @Published var showJoinGroupSheet = false
    @Published var showCreateGroupSheet = false
    @Published private(set) var showSearchBar = false
    @Published private(set) var showScrollToTopBtn = false

    let router: Router<AppRoute>
    var hasMoreGroups: Bool = true
    private var lastDocument: DocumentSnapshot?
    private var groupMembers: [AppUser] = []

    var filteredGroups: [GroupInformation] {
        guard case .hasGroup = groupListState else { return [] }

        switch selectedTab {
        case .all:
            return searchedGroup.isEmpty ? combinedGroups : combinedGroups.filter { $0.group.name.localizedCaseInsensitiveContains(searchedGroup) }
        case .settled:
            return searchedGroup.isEmpty ? combinedGroups.filter { $0.userBalance == 0 } : combinedGroups.filter { $0.userBalance == 0 &&
                $0.group.name.localizedCaseInsensitiveContains(searchedGroup) }
        case .unsettled:
            return searchedGroup.isEmpty ? combinedGroups.filter { $0.userBalance != 0 } : combinedGroups.filter { $0.userBalance != 0 &&
                $0.group.name.localizedCaseInsensitiveContains(searchedGroup) }
        }
    }

    init(router: Router<AppRoute>) {
        self.router = router
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(handleAddGroup(notification:)), name: .addGroup, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleUpdateGroup(notification:)), name: .updateGroup, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDeleteGroup(notification:)), name: .deleteGroup, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleJoinGroup(notification:)), name: .joinGroup, object: nil)

        fetchGroupsInitialData()
    }

    func fetchGroupsInitialData() {
        Task {
            await fetchGroups()
            await fetchLatestUser()
        }
    }

    // MARK: - Data Loading
    func fetchGroups() async {
        guard let userId = preference.user?.id else { return }

        do {
            let result = try await groupRepository.fetchGroupsBy(userId: userId, limit: GROUPS_LIMIT)

            self.groups = result.data
            self.lastDocument = result.lastDocument
            self.hasMoreGroups = !(result.data.count < self.GROUPS_LIMIT)

            let sortedGroups = try await self.processNewGroups(newGroups: result.data)

            self.currentViewState = .initial
            self.combinedGroups = sortedGroups
            self.groupListState = sortedGroups.isEmpty ? .noGroup : .hasGroup
        } catch {
            handleServiceError()
        }
    }

    func loadMoreGroups() {
        Task {
            await fetchMoreGroups()
        }
    }

    private func fetchMoreGroups() async {
        guard hasMoreGroups, let userId = preference.user?.id else { return }

        do {
            let result = try await groupRepository.fetchGroupsBy(userId: userId, limit: GROUPS_LIMIT, lastDocument: lastDocument)

            self.groups.append(contentsOf: result.data)
            self.lastDocument = result.lastDocument
            self.hasMoreGroups = !(result.data.count < self.GROUPS_LIMIT)

            let sortedGroups = try await self.processNewGroups(newGroups: result.data)

            self.currentViewState = .initial
            self.combinedGroups.append(contentsOf: sortedGroups)
            self.groupListState = self.combinedGroups.isEmpty ? .noGroup : .hasGroup
        } catch {
            self.currentViewState = .initial
            showToastForError()
        }
    }

    private func processNewGroups(newGroups: [Groups]) async throws -> [GroupInformation] {
        var indexedGroups: [(index: Int, groupInfo: GroupInformation)] = []

        // Fetch detailed group information for each group and maintain the original index
        for (index, group) in newGroups.enumerated() {
            let groupInfo = try await fetchGroupInformation(group: group)
            indexedGroups.append((index: index, groupInfo: groupInfo))
        }

        // Sort the group information by the original index
        return indexedGroups.sorted(by: { $0.index < $1.index }).map { $0.groupInfo }
    }

    private func fetchGroupInformation(group: Groups) async throws -> GroupInformation {
        let members = try await groupRepository.fetchMembersBy(groupId: group.id ?? "")

        let userId = self.preference.user?.id ?? ""
        let memberBalance = self.getMembersBalance(group: group, memberId: userId)
        let memberOwingAmount = calculateExpensesSimplified(userId: userId, memberBalances: group.balances)

        return GroupInformation(group: group,
                                userBalance: memberBalance,
                                memberOweAmount: memberOwingAmount,
                                members: members,
                                hasExpenses: true)
    }

    private func getMembersBalance(group: Groups, memberId: String) -> Double {
        if let index = group.balances.firstIndex(where: { $0.id == memberId }) {
            return group.balances[index].balance
        }
        return 0
    }

    private func fetchLatestUser() async {
        guard let userId = preference.user?.id else { return }

        do {
            let user = try await userRepository.fetchLatestUserBy(userID: userId)
            if let user {
                self.totalOweAmount = user.totalOweAmount
            }
        } catch {
            handleServiceError()
        }
    }

    private func fetchUserData(for userId: String) async {
        if !groupMembers.contains(where: { $0.id == userId }) {
            do {
                let user = try await userRepository.fetchUserBy(userID: userId)
                if let user {
                    self.groupMembers.append(user)
                }
            } catch {
                showToastForError()
            }
        }
    }

    private func fetchGroup(groupId: String) async -> Groups? {
        do {
            return try await groupRepository.fetchGroupBy(id: groupId)
        } catch {
            showToastForError()
            return nil
        }
    }
}

// MARK: - User Actions

extension GroupListViewModel {
    func getMemberData(from members: [AppUser], of id: String) -> AppUser? {
        return members.first(where: { $0.id == id })
    }

    func handleCreateGroupBtnTap() {
        selectedGroup = nil
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
        if groups.isEmpty {
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
        guard case .hasGroup = groupListState else { return }
        let settledGroups = combinedGroups.filter { $0.userBalance == 0 }
        let unsettledGroups = combinedGroups.filter { $0.userBalance != 0 }

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
            showCreateGroupSheet = true
        case .deleteGroup:
            handleDeleteGroupTap(group: group)
        }
    }

    func handleDeleteGroupTap(group: Groups?) {
        alert = .init(title: "Delete Group",
                      message: "Are you ABSOLUTELY sure you want to delete this group? This will remove this group for ALL users involved, not just yourself.",
                      positiveBtnTitle: "Delete",
                      positiveBtnAction: {
                        Task {
                            await self.deleteGroup(group: group)
                        }
                      },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false }, isPositiveBtnDestructive: true)
        showAlert = true
    }

    private func deleteGroup(group: Groups?) async {
        guard let group else { return }
        do {
            try await groupRepository.deleteGroup(group: group)
            NotificationCenter.default.post(name: .deleteGroup, object: group)
        } catch {
            showToastForError()
        }
    }

    @objc private func handleJoinGroup(notification: Notification) {
        guard let joinedGroupId = notification.object as? String else { return }

        if self.combinedGroups.contains(where: { $0.group.id == joinedGroupId }) { return }
        Task {
            if let group = await fetchGroup(groupId: joinedGroupId) {
                await self.processGroup(group: group, isNewGroup: true)
            }
        }
    }

    @objc private func handleAddGroup(notification: Notification) {
        guard let addedGroup = notification.object as? Groups else { return }

        // Check if the group already exists in combinedGroups
        if combinedGroups.contains(where: { $0.group.id == addedGroup.id }) { return }
        Task {
            await processGroup(group: addedGroup, isNewGroup: true)
        }
    }

    @objc private func handleUpdateGroup(notification: Notification) {
        guard let updatedGroup = notification.object as? Groups else { return }
        Task {
            await processGroup(group: updatedGroup, isNewGroup: false)
        }
    }

    @objc private func handleDeleteGroup(notification: Notification) {
        guard let deletedGroup = notification.object as? Groups else { return }
        withAnimation { self.combinedGroups.removeAll { $0.group.id == deletedGroup.id } }
        self.showToastFor(toast: .init(type: .success, title: "Success", message: "Group deleted successfully"))
    }

    private func processGroup(group: Groups, isNewGroup: Bool) async {
        let userId = preference.user?.id ?? ""
        let memberBalance = getMembersBalance(group: group, memberId: userId)
        let memberOwingAmount = calculateExpensesSimplified(userId: userId, memberBalances: group.balances)

        for memberId in group.members {
            await fetchUserData(for: memberId)
        }

        let groupInfo = GroupInformation(
            group: group,
            userBalance: memberBalance,
            memberOweAmount: memberOwingAmount,
            members: self.groupMembers,
            hasExpenses: group.hasExpenses
        )

        if isNewGroup {
            self.combinedGroups.insert(groupInfo, at: 0)
            if self.combinedGroups.count == 1 {
                self.groupListState = .hasGroup
            }
        } else {
            if let index = self.combinedGroups.firstIndex(where: { $0.group.id == group.id }) {
                self.combinedGroups[index] = groupInfo
            }
        }
    }

    // MARK: - Error Handling
    private func handleServiceError() {
        if !networkMonitor.isConnected {
            currentViewState = .noInternet
        } else {
            currentViewState = .somethingWentWrong
        }
    }
}

// MARK: - Group States
extension GroupListViewModel {
    enum ViewState {
        case initial
        case loading
        case noInternet
        case somethingWentWrong
    }

    enum GroupListState {
        case noGroup
        case hasGroup
    }
}
