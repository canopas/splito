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
    @Published var selectedPayers: [String: Double]

    @Published var isMultiplePayerselected: Bool = false

    @Published var currentViewState: ViewState = .initial
    @Published private(set) var amount: Double = 0

    var onPayerSelection: (([String: Double]) -> Void)
    private let router: Router<AppRoute>?

    init(router: Router<AppRoute>?, groupId: String, amount: Double, selectedPayers: [String: Double], onPayerSelection: @escaping (([String: Double]) -> Void)) {
        self.router = router
        self.groupId = groupId
        self.amount = amount
        self.selectedPayers = selectedPayers
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
                self.currentViewState = users.isEmpty ? .noMember : .hasMembers(users)
            }.store(in: &cancelable)
    }

    func handlePayerSelection(user: AppUser) {
        selectedPayers = [user.id: amount]
        onPayerSelection([user.id: amount])
    }

    func handleMultiplePayerTap() {
        router?.push(.ChooseMultiplePayerView(groupId: groupId, amount: amount, onPayerSelection: { payer in
            self.onPayerSelection(payer)
        }))
    }
}

extension ChoosePayerViewModel {
    enum ViewState {
        case initial
        case loading
        case noMember
        case hasMembers([AppUser])
    }
}
