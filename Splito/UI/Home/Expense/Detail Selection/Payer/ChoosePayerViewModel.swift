//
//  ChoosePayerViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 27/03/24.
//

import Data
import BaseStyle

class ChoosePayerViewModel: BaseViewModel, ObservableObject {

    @Inject var groupRepository: GroupRepository

    @Published var groupId: String
    @Published var selectedPayers: [String: Double]

    @Published var currentViewState: ViewState = .loading
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

        fetchInitialViewData()
    }

    func fetchInitialViewData() {
        Task {
            await fetchGroupWithMembers()
        }
    }

    // MARK: - Data Loading
    private func fetchGroupWithMembers() async {
        do {
            let group = try await groupRepository.fetchGroupBy(id: groupId)
            guard let group else {
                currentViewState = .noMember
                return
            }
            let users = try await groupRepository.fetchMembersBy(memberIds: group.members)
            currentViewState = users.isEmpty ? .noMember : .hasMembers(users)
            LogD("ChoosePayerViewModel: \(#function) Group with members fetched successfully.")
        } catch {
            LogE("ChoosePayerViewModel: \(#function) Failed to fetch group with members: \(error).")
            handleServiceError()
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

        router?.push(.ChooseMultiplePayerView(groupId: groupId, selectedPayers: selectedPayers,
                                              amount: amount, onPayerSelection: onPayerSelection))
    }

    func handleSaveBtnTap() {
        onPayerSelection(selectedPayers)
    }

    // MARK: - Error Handling
    private func handleServiceError() {
        if !networkMonitor.isConnected {
            currentViewState = .noInternet
        } else {
            currentViewState = .somethingWentWrong
        }
    }
}

extension ChoosePayerViewModel {
    enum ViewState: Equatable {
        case loading
        case noMember
        case hasMembers([AppUser])
        case noInternet
        case somethingWentWrong
    }
}
