//
//  GroupListViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 08/03/24.
//

import Data

class GroupListViewModel: BaseViewModel, ObservableObject {

    @Inject var preference: SplitoPreference
    @Inject var groupRepository: GroupRepository

    @Published var groupListState: GroupListState = .noGroup
    @Published var currentViewState: ViewState = .initial

    @Published var showGroupMenu = false

    private let router: Router<AppRoute>

    init(router: Router<AppRoute>) {
        self.router = router
        super.init()
        fetchGroups()
    }

    func fetchGroups() {
        guard let userId = preference.user?.id else { return }

        currentViewState = .loading
        groupRepository.fetchGroups(userId: userId)
            .sink { [weak self] completion in
                switch completion {
                case .finished:
                    return
                case .failure(let error):
                    self?.currentViewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] groups in
                guard let self else { return }
                self.currentViewState = .initial
                self.groupListState = groups.isEmpty ? .noGroup : .hasGroup(groups: groups)
            }.store(in: &cancelable)
    }

    func handleCreateGroupBtnTap() {
        router.push(.CreateGroupView(group: nil))
    }

    func handleJoinGroupBtnTap() {
        router.push(.JoinMemberView)
    }

    func handleGroupItemTap(_ group: Groups) {
        if let id = group.id {
            router.push(.GroupHomeView(groupId: id))
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
        case hasGroup(groups: [Groups])

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
