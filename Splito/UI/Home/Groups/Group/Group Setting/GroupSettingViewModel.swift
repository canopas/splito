//
//  GroupSettingViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 15/03/24.
//

import Data
import Combine
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
    }

    // MARK: - Data Loading
    func fetchGroupDetails() {
        groupRepository.fetchGroupBy(id: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] group in
                guard let self, let group else { return }
                self.group = group
                self.checkForGroupAdmin()
                self.fetchGroupMembers()
            }.store(in: &cancelable)
    }

    private func fetchGroupMembers() {
        groupRepository.fetchMembersBy(groupId: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] members in
                guard let self else { return }
                self.sortGroupMembers(members: members)
                self.currentViewState = .initial
            }.store(in: &cancelable)
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
        guard let userId = preference.user?.id else { return }

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
        guard let userId = preference.user?.id, let group else { return }
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

    func dismissEditGroupSheet() {
        showEditGroupSheet = false
        fetchGroupDetails()
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
                      positiveBtnAction: { self.removeMemberFromGroup(memberId: memberId) },
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
                      positiveBtnAction: { self.removeMemberFromGroup(memberId: memberId) },
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

    private func removeMemberFromGroup(memberId: String) {
        guard let group, let userId = preference.user?.id else {
            LogE("GroupSettingViewModel: \(#function) group not found.")
            return
        }

        currentViewState = .loading
        groupRepository.removeMemberFrom(group: group, memberId: memberId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                    self?.currentViewState = .initial
                }
            } receiveValue: { _ in
                self.currentViewState = .initial
                if userId == memberId {
                    self.goBackToGroupList()
                } else {
                    self.showAlert = false
                    withAnimation {
                        if let index = self.members.firstIndex(where: { $0.id == memberId }) {
                            self.members.remove(at: index)
                        }
                    }
                    self.showToastFor(toast: ToastPrompt(type: .success, title: "Success", message: "Group member removed"))
                }
            }.store(in: &cancelable)
    }

    func handleDeleteGroupTap() {
        alert = .init(title: "Delete Group",
                      message: "Are you ABSOLUTELY sure you want to delete this group? This will remove this group for ALL users involved, not just yourself.",
                      positiveBtnTitle: "Delete",
                      positiveBtnAction: { self.deleteGroup() },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false }, isPositiveBtnDestructive: true)
        showAlert = true
    }

    private func deleteGroup() {
        guard let group else { return }

        currentViewState = .loading
        groupRepository.deleteGroup(group: group)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { _ in
                self.currentViewState = .initial
                self.goBackToGroupList()
            }.store(in: &cancelable)
    }

    // MARK: - Navigation
    func goBackToGroupList() {
        router.popToRoot()
    }

    // MARK: - Error Handling
    private func handleServiceError(_ error: ServiceError) {
        currentViewState = .initial
        showToastFor(error)
    }
}

// MARK: - Group State
extension GroupSettingViewModel {
    enum ViewState {
        case initial
        case loading
        case hasMembers
    }

    enum MemberRemoveType: Equatable {
        case remove
        case leave
    }
}
