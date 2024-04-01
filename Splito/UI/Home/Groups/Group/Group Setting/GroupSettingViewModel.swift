//
//  GroupSettingViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 15/03/24.
//

import Data
import Combine

class GroupSettingViewModel: BaseViewModel, ObservableObject {

    @Inject var groupRepository: GroupRepository

    private let groupId: String
    private let router: Router<AppRoute>

    @Published var group: Groups?
    @Published var members: [AppUser] = []
    @Published var currentViewState: ViewState = .initial

    init(router: Router<AppRoute>, groupId: String) {
        self.router = router
        self.groupId = groupId

        super.init()

        fetchGroup()
        fetchGroupMembers()
    }

    func fetchGroup() {
        currentViewState = .loading
        groupRepository.fetchGroupBy(id: groupId)
            .sink { [weak self] completion in
                switch completion {
                case .finished:
                    return
                case .failure(let error):
                    self?.currentViewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] group in
                guard let self, let group else { return }
                self.currentViewState = .success(group: group)
            }.store(in: &cancelable)
    }

    func fetchGroupMembers() {
        // Show loader for this method
        groupRepository.fetchMembersBy(groupId: groupId)
            .sink { [weak self] completion in
                switch completion {
                case .finished:
                    return
                case .failure(let error):
                    self?.showToastFor(error)
                }
            } receiveValue: { users in
                self.members = users
            }.store(in: &cancelable)
    }

    func handleEditGroupTap() {
        router.push(.CreateGroupView)
    }

    func handleAddMemberTap() {
        router.push(.InviteMemberView(groupId: groupId))
    }
}

// MARK: - Group State
extension GroupSettingViewModel {
    enum ViewState {
        case initial
        case loading
        case success(group: Groups)
        case hasMembers
    }
}
