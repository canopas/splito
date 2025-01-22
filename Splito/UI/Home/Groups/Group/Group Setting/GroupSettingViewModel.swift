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

        NotificationCenter.default.addObserver(self, selector: #selector(handleUpdateGroup(notification:)),
                                               name: .updateGroup, object: nil)
    }

    func fetchInitialGroupData() {
        Task {
            await fetchGroupDetails()
        }
    }

    // MARK: - Data Loading
    private func fetchGroupDetails() async {
        do {
            group = try await groupRepository.fetchGroupBy(id: groupId)
            await fetchGroupMembers()
            checkForGroupAdmin()
            currentViewState = .initial
            LogD("GroupSettingViewModel: \(#function) Group fetched successfully.")
        } catch {
            LogE("GroupSettingViewModel: \(#function) Failed to fetch group \(groupId): \(error).")
            handleServiceError()
        }
    }

    private func fetchGroupMembers() async {
        guard let group else {
            currentViewState = .initial
            return
        }

        do {
            let members = try await groupRepository.fetchMembersBy(memberIds: group.members)
            sortGroupMembers(members: members)
            LogD("GroupSettingViewModel: \(#function) Group members fetched successfully.")
        } catch {
            LogE("GroupSettingViewModel: \(#function) Failed to fetch group members: \(error).")
            handleServiceError()
        }
    }

    // MARK: - Helper Methods

    func getMembersBalance(memberId: String) -> [String: Double] {
        guard let group else {
            LogE("GroupSettingViewModel: \(#function) group not found.")
            return [:]
        }

        guard let memberBalance = group.balances.first(where: { $0.id == memberId })?.balanceByCurrency else {
            LogE("GroupSettingViewModel: \(#function) Member's balance not found from balances.")
            return [:]
        }

        var filteredBalances: [String: Double] = [:]
        for (currency, balanceInfo) in memberBalance {
            if balanceInfo.balance == 0 { continue }
            filteredBalances[currency] = balanceInfo.balance
        }

        if filteredBalances.isEmpty { // If no non-zero balances, fallback to original data
            return memberBalance.mapValues { $0.balance }
        }

        return filteredBalances
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
        guard let user = preference.user else { return }
        showLeaveGroupAlert(member: user)
        showAlert = true
    }

    func handleMemberTap(member: AppUser) {
        guard let userId = preference.user?.id else { return }
        if userId == member.id {
            showLeaveGroupDialog = true
            showLeaveGroupAlert(member: member)
        } else {
            showRemoveMemberDialog = isAdmin
            showRemoveMemberAlert(member: member)
        }
    }

    private func hasOutstandingBalance(_ memberBalance: [String: Double]) -> Bool {
        let epsilon = 1e-10
        return !memberBalance.allSatisfy { abs($0.value) < epsilon }
    }

    private func showRemoveMemberAlert(member: AppUser) {
        let memberBalance = getMembersBalance(memberId: member.id)
        guard !hasOutstandingBalance(memberBalance) else {
            memberRemoveType = .remove
            showDebtOutstandingAlert(memberId: member.id)
            return
        }

        alert = .init(title: "Remove from group?",
                      message: "Are you sure you want to remove this member from the group?",
                      positiveBtnTitle: "Remove", positiveBtnAction: { self.removeMemberFromGroup(member: member) },
                      negativeBtnTitle: "Cancel", negativeBtnAction: { self.showAlert = false })
    }

    private func showLeaveGroupAlert(member: AppUser) {
        let memberBalance = getMembersBalance(memberId: member.id)
        guard !hasOutstandingBalance(memberBalance) else {
            memberRemoveType = .leave
            showDebtOutstandingAlert(memberId: member.id)
            return
        }

        alert = .init(title: "Leave Group?",
                      message: "Are you absolutely sure you want to leave this group?",
                      positiveBtnTitle: "Leave",
                      positiveBtnAction: { [weak self] in self?.removeMemberFromGroup(member: member) },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { [weak self] in self?.showAlert = false })
    }

    private func showDebtOutstandingAlert(memberId: String) {
        let leaveText = "You can't leave this group because you have outstanding debts with other group members. Please make sure all of your debts have been settle up, and try again."

        let memberName = members.first(where: { $0.id == memberId })?.firstName ?? ""
        let removeText = "You can't remove \(memberName) from this group because they have outstanding debts with other group members. Please make sure all of \(memberName)'s debts have been settle up, and try again."

        alert = .init(title: "Whoops!", message: memberRemoveType == .leave ? leaveText : removeText,
                      negativeBtnTitle: "Ok", negativeBtnAction: { [weak self] in self?.showAlert = false })
    }

    private func removeMemberFromGroup(member: AppUser) {
        guard let group, let userId = preference.user?.id else {
            LogE("GroupSettingViewModel: \(#function) group not found.")
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.groupRepository.removeMemberFrom(group: group, removedMember: member)

                if userId == member.id {
                    NotificationCenter.default.post(name: .leaveGroup, object: group)
                    self.goBackToGroupList()
                } else {
                    self.showAlert = false
                    withAnimation {
                        if let index = self.members.firstIndex(where: { $0.id == member.id }) {
                            self.members.remove(at: index)
                        }
                    }
                    self.group?.members = self.members.map { $0.id }
                    NotificationCenter.default.post(name: .updateGroup, object: self.group)
                    self.showToastFor(toast: ToastPrompt(type: .success, title: "Success", message: "Group member removed."))
                }
                LogD("GroupSettingViewModel: \(#function) Member removed successfully.")
            } catch {
                self.currentViewState = .initial
                LogE("GroupSettingViewModel: \(#function) Failed to remove member \(member.id): \(error).")
                self.showToastForError()
            }
        }
    }

    func handleDeleteGroupTap() {
        alert = .init(title: "Delete Group",
                      message: "Are you ABSOLUTELY sure you want to delete this group? This will remove this group for ALL users involved, not just yourself.",
                      positiveBtnTitle: "Delete",
                      positiveBtnAction: { [weak self] in self?.deleteGroup() },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { [weak self] in self?.showAlert = false },
                      isPositiveBtnDestructive: true)
        showAlert = true
    }

    private func deleteGroup() {
        guard let group else { return }
        Task { [weak self] in
            do {
                self?.currentViewState = .loading
                try await self?.groupRepository.deleteGroup(group: group)
                NotificationCenter.default.post(name: .deleteGroup, object: group)
                self?.currentViewState = .initial
                self?.goBackToGroupList()
                LogD("GroupSettingViewModel: \(#function) Group deleted successfully.")
            } catch {
                self?.currentViewState = .initial
                LogE("GroupSettingViewModel: \(#function) Failed to delete group \(self?.groupId ?? "nil"): \(error).")
                self?.showToastForError()
            }
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
