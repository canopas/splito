//
//  GroupSettingViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 15/03/24.
//

import Data
import Combine
import BaseStyle

class GroupSettingViewModel: BaseViewModel, ObservableObject {

    @Inject var preference: SplitoPreference
    @Inject var groupRepository: GroupRepository

    private let groupId: String
    private let router: Router<AppRoute>

    @Published var isAdmin = false
    @Published var showLeaveGroupDialog = false
    @Published var showRemoveMemberDialog = false

    @Published var group: Groups?
    @Published var members: [AppUser] = []
    @Published var currentViewState: ViewState = .initial

    init(router: Router<AppRoute>, groupId: String) {
        self.router = router
        self.groupId = groupId

        super.init()

        fetchGroupDetails()
    }

    // MARK: - Data Loading

    func fetchGroupDetails() {
        currentViewState = .loading
        groupRepository.fetchGroupBy(id: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] group in
                guard let self, let group else { return }
                self.group = group
                self.fetchGroupMembers()
            }.store(in: &cancelable)
    }

    func fetchGroupMembers() {
        groupRepository.fetchMembersBy(groupId: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { [weak self] users in
                guard let self else { return }
                self.members = users
                self.checkForGroupAdmin()
                self.currentViewState = .initial
            }.store(in: &cancelable)
    }

    func checkForGroupAdmin() {
        guard let userId = preference.user?.id, let group else { return }
        isAdmin = userId == group.createdBy
    }

    // MARK: - User Actions

    func handleEditGroupTap() {
        router.push(.CreateGroupView(group: group))
    }

    func handleAddMemberTap() {
        router.push(.InviteMemberView(groupId: groupId))
    }

    func handleMemberTap(member: AppUser) {
        if let userId = preference.user?.id, userId == member.id {
            showLeaveGroupDialog = true
            alert = .init(title: "Leave Group?",
                          message: "Are you absolutely sure you want to leave this group?",
                          positiveBtnTitle: "Leave",
                          positiveBtnAction: { self.removeMemberFromGroup(memberId: member.id) },
                          negativeBtnTitle: "Cancel",
                          negativeBtnAction: { self.showAlert = false })
        } else {
            showRemoveMemberDialog = true
            alert = .init(title: "Remove from group?",
                          message: "Are you sure you want to remove this member from the group?",
                          positiveBtnTitle: "Remove",
                          positiveBtnAction: { self.removeMemberFromGroup(memberId: member.id) },
                          negativeBtnTitle: "Cancel",
                          negativeBtnAction: { self.showAlert = false })
        }
    }

    func handleLeaveGroupTap() {
        guard let userId = preference.user?.id else { return }
        alert = .init(title: "Leave Group?",
                      message: "Are you absolutely sure you want to leave this group?",
                      positiveBtnTitle: "Leave",
                      positiveBtnAction: { self.removeMemberFromGroup(memberId: userId) },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false })
        showAlert = true
    }

    func removeMemberFromGroup(memberId: String) {
        guard let group else { return }
        guard let userId = preference.user?.id else { return }
        currentViewState = .loading
        groupRepository.removeMemberFrom(group: group, memberId: memberId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handleServiceError(error)
                }
            } receiveValue: { _ in
                self.currentViewState = .initial
                if userId == memberId {
                    self.goBackToGroupList()
                } else {
                    self.showAlert = false
                    self.showToastFor(toast: ToastPrompt(type: .success, title: "", message: "Group member removed"))
                }
            }.store(in: &cancelable)
    }

    func handleDeleteGroupTap() {
        alert = .init(title: "Delete Group",
                      message: "Are you ABSOLUTELY sure you want to leave this group? This will remove the group for ALL users involved, not just yourself.",
                      positiveBtnTitle: "Delete",
                      positiveBtnAction: { self.deleteGroupWithMembers() },
                      negativeBtnTitle: "Cancel",
                      negativeBtnAction: { self.showAlert = false }, isPositiveBtnDestructive: true)
        showAlert = true
    }

    func deleteGroupWithMembers() {
        currentViewState = .loading
        groupRepository.deleteGroup(groupID: groupId)
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
}
