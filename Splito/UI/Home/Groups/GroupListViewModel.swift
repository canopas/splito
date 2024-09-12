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
    @Published var combinedGroups: [GroupInformation] = []
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

        Task {
            await fetchGroups()
            await fetchLatestUser()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Data Loading
    func fetchGroups() async {
        guard let userId = preference.user?.id else { return }

        do {
            // Fetch the initial group data
            let result = try await groupRepository.fetchGroupsBy(userId: userId, limit: GROUPS_LIMIT)

            // Update the state based on the fetched data
            self.groups = result.data
            self.lastDocument = result.lastDocument
            self.hasMoreGroups = !(result.data.count < GROUPS_LIMIT)

            // Fetch group information for each group and maintain original index
            var indexedGroups: [(index: Int, groupInfo: GroupInformation)] = []

            for (index, group) in result.data.enumerated() {
                let groupInfo = try await fetchGroupInformation(group: group)
                indexedGroups.append((index: index, groupInfo: groupInfo))
            }

            // Sort by index to preserve the original order
            let sortedGroups = indexedGroups.sorted(by: { $0.index < $1.index }).map { $0.groupInfo }

            // Update the UI with the new state
            self.currentViewState = .initial
            self.combinedGroups = sortedGroups
            self.groupListState = sortedGroups.isEmpty ? .noGroup : .hasGroup

        } catch {
            // Handle errors and update the view state
            self.currentViewState = .initial
            self.showToastFor(error as! ServiceError)
        }
    }

    func fetchMoreGroups() async {
        guard hasMoreGroups, let userId = preference.user?.id else { return }

        do {
            // Fetch more groups from the repository
            let result = try await groupRepository.fetchGroupsBy(userId: userId, limit: GROUPS_LIMIT, lastDocument: lastDocument)

            // Append the newly fetched groups to the existing groups
            self.groups.append(contentsOf: result.data)
            self.lastDocument = result.lastDocument
            self.hasMoreGroups = !(result.data.count < GROUPS_LIMIT)

            // Fetch detailed group information for each group and maintain the original index
            var indexedGroups: [(index: Int, groupInfo: GroupInformation)] = []

            for (index, group) in result.data.enumerated() {
                let groupInfo = try await fetchGroupInformation(group: group)
                indexedGroups.append((index: index, groupInfo: groupInfo))
            }

            // Sort the group information by the original index
            let sortedGroups = indexedGroups.sorted(by: { $0.index < $1.index }).map { $0.groupInfo }

            // Update the UI state
            self.currentViewState = .initial
            self.combinedGroups.append(contentsOf: sortedGroups)
            self.groupListState = self.combinedGroups.isEmpty ? .noGroup : .hasGroup

        } catch {
            // Handle any errors
            self.currentViewState = .initial
            self.showToastFor(error as! ServiceError)
        }
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
            self.showToastFor(error as! ServiceError)
        }
    }

    private func fetchUserData(for userId: String?, completion: ((AppUser) -> Void)? = nil) async {
        guard let userId else { return }

        if let existingUser = groupMembers.first(where: { $0.id == userId }) {
            completion?(existingUser) // Return the available user from groupMembers
        } else {
            do {
                let user = try await userRepository.fetchUserBy(userID: userId)
                if let user {
                    self.groupMembers.append(user)
                    completion?(user)
                }
            } catch {
                self.showToastFor(error as! ServiceError)
            }
        }
    }

    private func fetchGroup(groupId: String, completion: @escaping (Groups?) -> Void) async {
        do {
            let group = try await groupRepository.fetchGroupBy(id: groupId)
            completion(group)
        } catch {
            self.showToastFor(error as! ServiceError)
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
            self.showToastFor(error as! ServiceError)
        }
    }

    @objc private func handleJoinGroup(notification: Notification) async {
        guard let joinedGroupId = notification.object as? String else { return }

        Task {
            await fetchGroup(groupId: joinedGroupId, completion: { group in
                if let group {
                    if self.combinedGroups.contains(where: { $0.group.id == group.id }) { return }
                    Task {
                        await self.processGroup(group: group, isNewGroup: true)
                    }
                }
            })
        }
    }

    @objc private func handleAddGroup(notification: Notification) async {
        guard let addedGroup = notification.object as? Groups else { return }

        // Check if the group already exists in combinedGroups
        if combinedGroups.contains(where: { $0.group.id == addedGroup.id }) { return }
        Task {
            await processGroup(group: addedGroup, isNewGroup: true)
        }
    }

    @objc private func handleUpdateGroup(notification: Notification) async {
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

        let dispatchGroup = DispatchGroup()

        for memberId in group.members {
            if !groupMembers.contains(where: { $0.id == memberId }) {
                dispatchGroup.enter()

                Task {
                    await fetchUserData(for: memberId) { user in
                        self.groupMembers.append(user)
                        dispatchGroup.leave()
                    }
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
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
    }
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
        case hasGroup

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
