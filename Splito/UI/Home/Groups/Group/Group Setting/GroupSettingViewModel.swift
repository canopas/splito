//
//  GroupSettingViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 15/03/24.
//

import Data
import BaseStyle
import SwiftUI

class GroupSettingViewModel: BaseViewModel, ObservableObject {

    @Inject private var preference: SplitoPreference
    @Inject private var groupRepository: GroupRepository

    @Published private(set) var isAdmin = false
    @Published var showLeaveGroupDialog = false
    @Published var showRemoveMemberDialog = false
    @Published var showEditGroupSheet = false
    @Published var showAddMemberSheet = false

    @Published private(set) var group: Groups?
    @Published private(set) var members: [AppUser] = []
    @Published private(set) var currentViewState: ViewState = .loading

    private let groupId: String
    let router: Router<AppRoute>
    private var memberRemoveType: MemberRemoveType = .leave

    init(router: Router<AppRoute>, groupId: String) {
        self.router = router
        self.groupId = groupId
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(handleUpdateGroup(notification:)), name: .updateGroup, object: nil)
    }

    func fetchInitialGroupData() {
        Task {
            await fetchGroupDetails()
        }
    }

    // MARK: - Data Loading
    private func fetchGroupDetails() async {
        do {
            let group = try await groupRepository.fetchGroupBy(id: groupId)
            self.group = group
            self.checkForGroupAdmin()
            await fetchGroupMembers()
            currentViewState = .initial
        } catch {
            handleServiceError()
        }
    }

    private func fetchGroupMembers() async {
        do {
            let members = try await groupRepository.fetchMembersBy(groupId: groupId)
            sortGroupMembers(members: members)
        } catch {
            handleServiceError()
        }
    }

    // MARK: - Helper Methods

    func getMembersBalance(memberId: String) -> Double {
        guard let group else {
            LogE("GroupSettingViewModel: \(#function) group not found.")
            return 0
        }

        if let index = group.balances.firstIndex(where: { $0.id == memberId }) {
            return group.balances[index].balance
        }

        return 0
    }

    func sortGroupMembers(members: [AppUser]) {
        guard let userId = preference.user?.id else {
            currentViewState = .initial
            return
        }

        var sortedMembers = members
        sortedMembers.sort { (member1: AppUser, member2: AppUser) in
            if member1.id == userId {
                return true
            } else if member2.id == userId {
                return false
            } else {
                return member1.fullName < member2.fullName
            }
        }
        self.members = sortedMembers
    }

    func getMemberName(id: String, needFullName: Bool = false) -> String {
        guard let member = members.first(where: { $0.id == id }) else { return "" }
        return needFullName ? member.fullName : member.nameWithLastInitial
    }

    private func checkForGroupAdmin() {
        guard let userId = preference.user?.id, let group else {
            currentViewState = .initial
            return
        }
        isAdmin = userId == group.createdBy
    }

    // MARK: - User Actions

    func handleBackBtnTap() {
        router.pop()
    }

    func onRemoveAndLeaveFromGroupTap() {
        showAlert = true
    }

    func handleEditGroupTap() {
        showEditGroupSheet = true
    }

    func handleAddMemberTap() {
        showAddMemberSheet = true
    }

    func handleLeaveGroupTap() {
        guard let userId = preference.user?.id else { return }
        showLeaveGroupAlert(memberId: userId)
        showAlert = true
    }

    func handleMemberTap(memberId: String) {
        guard let userId = preference.user?.id else { return }
        if userId == memberId {
            showLeaveGroupDialog = true
            showLeaveGroupAlert(memberId: memberId)
        } else {
            showRemoveMemberDialog = isAdmin
            showRemoveMemberAlert(memberId: memberId)
        }
    }

    private func showRemoveMemberAlert(memberId: String) {
        let memberBalance = getMembersBalance(memberId: memberId)
        guard memberBalance == 0 else {
            memberRemoveType = .remove
            showDebtOutstandingAlert(memberId: memberId)
            return
        }

        alert = .init(title: "Remove from group?",
                      message: "Are you sure you want to remove this member from the group?",
                      positiveBtnTitle: "Remove",
                      positiveBtnAction: {
                        Task {
                            await self.removeMemberFromGroup(memberId: memberId)
                        }
                      },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false })
    }

    private func showLeaveGroupAlert(memberId: String) {
        let memberBalance = getMembersBalance(memberId: memberId)

        guard memberBalance == 0 else {
            memberRemoveType = .leave
            showDebtOutstandingAlert(memberId: memberId)
            return
        }

        alert = .init(title: "Leave Group?",
                      message: "Are you absolutely sure you want to leave this group?",
                      positiveBtnTitle: "Leave",
                      positiveBtnAction: {
                        Task {
                            await self.removeMemberFromGroup(memberId: memberId)
                        }
                      },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false })
    }

    private func showDebtOutstandingAlert(memberId: String) {
        let leaveText = "You can't leave this group because you have outstanding debts with other group members. Please make sure all of your debts have been settle up, and try again."

        let memberName = members.first(where: { $0.id == memberId })?.firstName ?? ""
        let removeText = "You can't remove \(memberName) from this group because they have outstanding debts with other group members. Please make sure all of \(memberName)'s debts have been settle up, and try again."

        alert = .init(title: "Whoops!",
                      message: memberRemoveType == .leave ? leaveText : removeText,
                      negativeBtnTitle: "Ok",
                      negativeBtnAction: { self.showAlert = false })
    }

    private func removeMemberFromGroup(memberId: String) async {
        guard let group, let userId = preference.user?.id else {
            LogE("GroupSettingViewModel: \(#function) group not found.")
            return
        }

        do {
            currentViewState = .loading
            try await groupRepository.removeMemberFrom(group: group, memberId: memberId)
            currentViewState = .initial

            if userId == memberId {
                NotificationCenter.default.post(name: .leaveGroup, object: group)
                goBackToGroupList()
            } else {
                showAlert = false
                withAnimation {
                    if let index = self.members.firstIndex(where: { $0.id == memberId }) {
                        self.members.remove(at: index)
                    }
                }
                showToastFor(toast: ToastPrompt(type: .success, title: "Success", message: "Group member removed"))
            }
        } catch {
            currentViewState = .initial
            showToastForError()
        }
    }

    func handleDeleteGroupTap() {
        alert = .init(title: "Delete Group",
                      message: "Are you ABSOLUTELY sure you want to delete this group? This will remove this group for ALL users involved, not just yourself.",
                      positiveBtnTitle: "Delete",
                      positiveBtnAction: {
                        Task {
                            await self.deleteGroup()
                        }
                      },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false }, isPositiveBtnDestructive: true)
        showAlert = true
    }

    private func deleteGroup() async {
        guard let group else { return }
        do {
            currentViewState = .loading
            try await groupRepository.deleteGroup(group: group)
            NotificationCenter.default.post(name: .deleteGroup, object: group)
            currentViewState = .initial
            goBackToGroupList()
        } catch {
            currentViewState = .initial
            showToastForError()
        }
    }

    @objc private func handleUpdateGroup(notification: Notification) {
        guard let updatedGroup = notification.object as? Groups else { return }
        group = updatedGroup
    }

    // MARK: - Navigation
    func goBackToGroupList() {
        router.popToRoot()
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

// MARK: - Group State
extension GroupSettingViewModel {
    enum ViewState {
        case initial
        case loading
        case hasMembers
        case noInternet
        case somethingWentWrong
    }

    enum MemberRemoveType: Equatable {
        case remove
        case leave
    }
}
