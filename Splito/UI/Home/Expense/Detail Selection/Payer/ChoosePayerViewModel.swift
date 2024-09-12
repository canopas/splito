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

        Task {
            await self.fetchMembers()
        }
    }

    // MARK: - Data Loading
    func fetchMembers() async {
        do {
            currentViewState = .loading
            let users = try await groupRepository.fetchMembersBy(groupId: groupId)
            currentViewState = users.isEmpty ? .noMember : .hasMembers(users)
        } catch {
            currentViewState = .initial
            showToastFor(error as! ServiceError)
        }
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
        router?.push(.ChooseMultiplePayerView(groupId: groupId, selectedPayers: selectedPayers, amount: amount, onPayerSelection: onPayerSelection))
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
