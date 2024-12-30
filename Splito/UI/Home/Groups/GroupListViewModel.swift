//
//  GroupListViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 08/03/24.
//

import Data
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

    @Published var selectedGroup: Groups?
    @Published var searchedGroup: String = ""
    @Published private(set) var totalOweAmount: Double = 0.0
    @Published private(set) var combinedGroups: [GroupInformation] = []

    @Published var showActionSheet = false
    @Published var showJoinGroupSheet = false
    @Published var showAddExpenseSheet = false
    @Published var showCreateGroupSheet = false
    @Published private(set) var showSearchBar = false
    @Published private(set) var showScrollToTopBtn = false

    let router: Router<AppRoute>
    var hasMoreGroups: Bool = true
    private var users: [AppUser] = []
    private var lastDocument: DocumentSnapshot?
    private var task: Task<Void, Never>?  // Reference to the current asynchronous task that fetches users

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
        NotificationCenter.default.addObserver(self, selector: #selector(handleLeaveGroup(notification:)), name: .leaveGroup, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleJoinGroup(notification:)), name: .joinGroup, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAddExpense(notification:)), name: .addExpense, object: nil)

        fetchGroupsInitialData()
        fetchLatestUser()
    }

    deinit {
        task?.cancel()
    }

    func fetchGroupsInitialData(needToReload: Bool = false) {
        lastDocument = nil
        Task {
            await fetchGroups(needToReload: needToReload)
        }
    }

    // MARK: - Data Loading
    private func fetchGroups(needToReload: Bool = false) async {
        guard let userId = preference.user?.id, hasMoreGroups || needToReload else {
            currentViewState = .initial
            return
        }

        do {
            let result = try await groupRepository.fetchGroupsBy(userId: userId, limit: GROUPS_LIMIT, lastDocument: lastDocument)
            let sortedGroups = try await self.processNewGroups(newGroups: result.data)
            combinedGroups = lastDocument == nil ? sortedGroups : (combinedGroups + sortedGroups)
            lastDocument = result.lastDocument
            hasMoreGroups = !(result.data.count < self.GROUPS_LIMIT)

            currentViewState = .initial
            groupListState = combinedGroups.isEmpty ? .noGroup : .hasGroup
            LogD("GroupListViewModel: \(#function) Groups fetched successfully.")
        } catch {
            LogE("GroupListViewModel: \(#function) Failed to fetch groups: \(error).")
            handleErrorState()
        }
    }

    func loadMoreGroups() {
        Task {
            await fetchGroups()
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
        let userId = preference.user?.id ?? ""
        let memberBalance = getMembersBalance(group: group, memberId: userId)
        let memberOwingAmount = calculateExpensesSimplified(userId: userId, memberBalances: group.balances)
        let members = try await fetchMembersDataBy(memberIds: group.members)

        return GroupInformation(group: group, userBalance: memberBalance, memberOweAmount: memberOwingAmount,
                                members: members, hasExpenses: true)
    }

    private func fetchMembersDataBy(memberIds: [String]) async throws -> [AppUser] {
        let missingMemberIds = memberIds.filter { memberId in
            !users.contains(where: { $0.id == memberId })
        }

        var fetchedMembers: [AppUser] = []
        try await withThrowingTaskGroup(of: AppUser?.self) { [weak self] groupTask in
            guard let self else { return }
            for memberId in missingMemberIds {
                groupTask.addTask {
                    try await self.groupRepository.fetchMemberBy(memberId: memberId)
                }
            }

            for try await fetchedMember in groupTask {
                if let member = fetchedMember {
                    fetchedMembers.append(member)
                }
            }
        }

        users.append(contentsOf: fetchedMembers)
        let groupMembers = users.filter { memberIds.contains($0.id) }
        return groupMembers
    }

    private func getMembersBalance(group: Groups, memberId: String) -> Double {
        if let index = group.balances.firstIndex(where: { $0.id == memberId }) {
            return group.balances[index].balance
        }
        return 0
    }

    private func fetchLatestUser() {
        guard let userId = preference.user?.id else {
            currentViewState = .initial
            return
        }

        task?.cancel() // Cancel the existing task if it's running
        task = Task { [unowned self] in
            totalOweAmount = preference.user?.totalOweAmount ?? 0
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds wait

            for await user in userRepository.fetchLatestUserBy(userID: userId) {
                if let user {
                    preference.user = user
                    totalOweAmount = user.totalOweAmount
                } else {
                    showToastForError()
                }
            }
        }
    }

    private func fetchGroup(groupId: String) async -> Groups? {
        do {
            let group = try await groupRepository.fetchGroupBy(id: groupId)
            LogD("GroupListViewModel: \(#function) Group fetched successfully.")
            return group
        } catch {
            showToastForError()
            LogE("GroupListViewModel: \(#function) Failed to fetch group \(groupId): \(error).")
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

    func openAddExpenseSheet() {
        showAddExpenseSheet = true
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
        if (combinedGroups.isEmpty) ||
            (selectedTab == .unsettled && combinedGroups.filter({ $0.userBalance != 0 }).isEmpty) ||
            (selectedTab == .settled && combinedGroups.filter({ $0.userBalance == 0 }).isEmpty) {
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
                      positiveBtnAction: { [weak self] in
                        Task {
                            await self?.deleteGroup(group: group)
                        }
                      },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { [weak self] in self?.showAlert = false },
                      isPositiveBtnDestructive: true)
        showAlert = true
    }

    private func deleteGroup(group: Groups?) async {
        guard let group, let groupId = group.id else { return }

        do {
            try await groupRepository.deleteGroup(group: group)
            NotificationCenter.default.post(name: .deleteGroup, object: group)
            LogD("GroupListViewModel: \(#function) Group deleted successfully.")
        } catch {
            LogE("GroupListViewModel: \(#function) Failed to delete group \(groupId): \(error).")
            showToastForError()
        }
    }

    @objc private func handleJoinGroup(notification: Notification) {
        guard let joinedGroupId = notification.object as? String else { return }

        if self.combinedGroups.contains(where: { $0.group.id == joinedGroupId }) { return }
        Task {
            if let group = await fetchGroup(groupId: joinedGroupId) {
                await processGroup(group: group, isNewGroup: true)
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
        handleRemoveGroupAction(notification: notification, action: .deleteGroup)
    }

    @objc private func handleLeaveGroup(notification: Notification) {
        handleRemoveGroupAction(notification: notification, action: .leaveGroup)
    }

    @objc private func handleRemoveGroupAction(notification: Notification, action: Notification.Name) {
        guard let group = notification.object as? Groups else { return }

        withAnimation { combinedGroups.removeAll { $0.group.id == group.id } }

        showToastFor(toast: .init(type: .success, title: "Success",
                                  message: action == .deleteGroup ? "Group deleted successfully." : "Group left successfully."))
    }

    @objc private func handleAddExpense(notification: Notification) {
        guard let expenseInfo = notification.userInfo,
              let notificationGroupId = expenseInfo["groupId"] as? String else { return }

        Task {
            if let existingIndex = combinedGroups.firstIndex(where: { $0.group.id == notificationGroupId }) {
                if let updatedGroup = await fetchGroup(groupId: notificationGroupId) {
                    do {
                        let groupInformation = try await fetchGroupInformation(group: updatedGroup)
                        combinedGroups[existingIndex] = groupInformation
                        LogD("GroupListViewModel: \(#function) Group information fetched Successfully.")
                    } catch {
                        LogE("GroupListViewModel: \(#function) Failed to fetch group information: \(error).")
                        showToastForError()
                    }
                }
            }
        }
    }

    private func processGroup(group: Groups, isNewGroup: Bool) async {
        guard let userId = preference.user?.id else { return }

        let memberBalance = getMembersBalance(group: group, memberId: userId)
        let memberOwingAmount = calculateExpensesSimplified(userId: userId, memberBalances: group.balances)

        do {
            let groupMembers = try await fetchMembersDataBy(memberIds: group.members)
            let groupInfo = GroupInformation(group: group, userBalance: memberBalance, memberOweAmount: memberOwingAmount,
                                             members: groupMembers, hasExpenses: group.hasExpenses)
            if isNewGroup {
                combinedGroups.append(groupInfo)
                if combinedGroups.count == 1 {
                    groupListState = .hasGroup
                }
            } else {
                if let index = combinedGroups.firstIndex(where: { $0.group.id == group.id }) {
                    combinedGroups[index] = groupInfo
                }
            }

            // Sort the combinedGroups array based on the 'updatedAt' field
            combinedGroups.sort { (group1, group2) in
                return (group1.group.updatedAt > group2.group.updatedAt)
            }
            LogD("GroupListViewModel: \(#function) Members fetched successfully.")
        } catch {
            LogE("GroupListViewModel: \(#function) Failed to fetch members: \(error).")
            showToastForError()
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

    private func handleErrorState() {
        if lastDocument == nil {
            handleServiceError()
        } else {
            currentViewState = .initial
            showToastForError()
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
