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
                // Show only those groups in which the user is part of
                let filteredGroups = groups.filter { $0.createdBy == userId || $0.members.contains(where: { $0.userId == userId }) }
                self.currentViewState = .initial
                self.groupListState = filteredGroups.isEmpty ? .noGroup : .hasGroup(groups: filteredGroups)
            }.store(in: &cancelables)
    }

    func handleCreateGroupBtnTap() {
        router.push(.CreateGroupView)
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
            case .hasGroup(let groups):
                "hasGroup"
            }
        }
    }
}
