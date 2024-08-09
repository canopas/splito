//
//  ChoosePayerViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 27/03/24.
//

import Data
import Combine
import BaseStyle

class ChoosePayerViewModel: BaseViewModel, ObservableObject {

    @Inject var groupRepository: GroupRepository

    @Published var groupId: String
    @Published var selectedPayers: [String: Double]

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

    // MARK: - Data Loading
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

    // MARK: - User Actions
    func handlePayerSelection(user: AppUser) {
        selectedPayers = [user.id: amount]
    }

    func handleMultiplePayerTap() {
        guard amount > 0 else {
            showToastFor(toast: ToastPrompt(type: .warning, title: "Whoops!",
                                            message: "Please enter a cost for your expense first!"))
            return
        }
        router?.push(.ChooseMultiplePayerView(groupId: groupId, selectedPayers: selectedPayers, amount: amount, onPayerSelection: { payers in
            self.onPayerSelection(payers)
        }))
    }

    func handleSaveBtnTap() {
        onPayerSelection(selectedPayers)
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
