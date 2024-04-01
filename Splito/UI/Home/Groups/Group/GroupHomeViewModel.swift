//
//  GroupHomeViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 06/03/24.
//

import Data

class GroupHomeViewModel: BaseViewModel, ObservableObject {

    @Inject var groupRepository: GroupRepository

    @Published var groupState: GroupState = .noMember

    var group: Groups?
    private let groupId: String
    private let router: Router<AppRoute>

    init(router: Router<AppRoute>, groupId: String) {
        self.router = router
        self.groupId = groupId

        super.init()

        self.fetchGroup()
    }

    func fetchGroup() {
        groupRepository.fetchGroupBy(id: groupId)
            .sink { [weak self] completion in
                switch completion {
                case .finished:
                    return
                case .failure(let error):
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] group in
                guard let self, let group else { return }
                self.group = group
                self.groupState = group.members.count == 1 ? .noMember : .hasMembers
            }.store(in: &cancelable)
    }

    func handleCreateGroupClick() {
        router.push(.CreateGroupView)
    }

    func handleAddMemberClick() {
        router.push(.InviteMemberView(groupId: groupId))
    }

    func handleSettingButtonTap() {
        router.push(.GroupSettingView(groupId: groupId))
    }
}

// MARK: - Group State
extension GroupHomeViewModel {
    enum GroupState {
        case noGroup
        case noMember
        case hasMembers
    }
}
