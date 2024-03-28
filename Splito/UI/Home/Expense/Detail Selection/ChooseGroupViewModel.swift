//
//  ChooseGroupViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 27/03/24.
//

import Data
import Combine

class ChooseGroupViewModel: BaseViewModel, ObservableObject {

    @Inject var preference: SplitoPreference
    @Inject var groupRepository: GroupRepository

    @Published var groups: [Groups] = []
    @Published var selectedGroup: Groups?
    @Published var currentViewState: ViewState = .initial

    var onGroupSelection: ((Groups) -> Void)

    init(selectedGroup: Groups?, onGroupSelection: @escaping ((Groups) -> Void)) {
        self.selectedGroup = selectedGroup
        self.onGroupSelection = onGroupSelection
        super.init()
        self.fetchGroups()
    }

    func fetchGroups() {
        currentViewState = .loading
        groupRepository.fetchGroups(userId: preference.user?.id ?? "")
            .sink { [weak self] completion in
                switch completion {
                case .finished:
                    return
                case .failure(let error):
                    self?.currentViewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] groups in
                self?.currentViewState = groups.isEmpty ? .noGroups : .hasGroups(groups: groups)
                self?.groups = groups
            }
            .store(in: &cancelables)
    }

    func handleGroupSelection(group: Groups) {
        selectedGroup = group
        onGroupSelection(group)
    }
}

extension ChooseGroupViewModel {
    enum ViewState {
        case initial
        case loading
        case hasGroups(groups: [Groups])
        case noGroups
    }
}
