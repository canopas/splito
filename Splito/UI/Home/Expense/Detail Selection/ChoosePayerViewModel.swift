//
//  ChoosePayerViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 27/03/24.
//

import Data
import Combine

class ChoosePayerViewModel: BaseViewModel, ObservableObject {

    @Inject var groupRepository: GroupRepository

    @Published var groupId: String
    @Published var selectedPayer: AppUser?
    @Published var currentViewState: ViewState = .initial

    var onPayerSelection: ((AppUser) -> Void)

    init(groupId: String, selectedPayer: AppUser?, onPayerSelection: @escaping ((AppUser) -> Void)) {
        self.groupId = groupId
        self.selectedPayer = selectedPayer
        self.onPayerSelection = onPayerSelection
        super.init()

        self.fetchMembers()
    }

    func fetchMembers() {
        currentViewState = .loading
        groupRepository.fetchMembersBy(groupId: groupId)
            .sink { [weak self] completion in
                switch completion {
                case .finished:
                    return
                case .failure(let error):
                    self?.currentViewState = .initial
                    self?.showToastFor(error)
                }
            } receiveValue: { users in
                self.currentViewState = users.isEmpty ? .noUsers : .hasUser(users: users)
            }.store(in: &cancelable)
    }

    func handlePayerSelection(user: AppUser) {
        selectedPayer = user
        onPayerSelection(user)
    }
}

extension ChoosePayerViewModel {
    enum ViewState {
        case initial
        case loading
        case noUsers
        case hasUser(users: [AppUser])
    }
}
