//
//  SelectGroupViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 27/03/24.
//

import Data
import Combine

class SelectGroupViewModel: BaseViewModel, ObservableObject {

    @Inject var preference: SplitoPreference
    @Inject var groupRepository: GroupRepository

    @Published var selectedGroup: Groups?
    @Published var currentViewState: ViewState = .initial

    var onGroupSelection: ((Groups) -> Void)

    init(selectedGroup: Groups?, onGroupSelection: @escaping ((Groups) -> Void)) {
        self.selectedGroup = selectedGroup
        self.onGroupSelection = onGroupSelection
        super.init()

        Task {
            await self.fetchGroups()
        }
    }

    // MARK: - Data Loading
    func fetchGroups() async {
        currentViewState = .loading
        do {
            let (groups, _) = try await groupRepository.fetchGroupsBy(userId: preference.user?.id ?? "")
            currentViewState = groups.isEmpty ? .noGroups : .hasGroups(groups: groups)
        } catch {
            currentViewState = .initial
            handleServiceError(error)
        }
    }

    // MARK: - User Actions
    func handleGroupSelection(group: Groups) {
        selectedGroup = group
    }

    func handleDoneAction() {
        if let selectedGroup {
            onGroupSelection(selectedGroup)
        }
    }
}

extension SelectGroupViewModel {
    enum ViewState {
        case initial
        case loading
        case hasGroups(groups: [Groups])
        case noGroups
    }
}
