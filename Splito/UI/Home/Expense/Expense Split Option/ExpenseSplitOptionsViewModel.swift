//
//  ExpenseSplitOptionsViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 22/04/24.
//

import Data
import Combine

class ExpenseSplitOptionsViewModel: BaseViewModel, ObservableObject {

    @Inject var preference: SplitoPreference
    @Inject private var userRepository: UserRepository
    @Inject private var expenseRepository: ExpenseRepository

    @Published var splitAmount: Double = 0
    @Published var groupMembers: [AppUser] = []
    @Published var viewState: ViewState = .initial

    var members: [String] = []
    var selectedMembers: [String] = []

    var totalAmount: Double = 0
    var onMemberSelection: (([String]) -> Void)

    init(amount: Double, members: [String], onMemberSelection: @escaping (([String]) -> Void)) {
        self.totalAmount = amount
        self.members = members
        self.onMemberSelection = onMemberSelection
        super.init()

        fetchUsersData()
    }

    func fetchUsersData() {
        var users: [AppUser] = []
        let queue = DispatchGroup()

        self.viewState = .loading

        for memberId in members {
            queue.enter()
            userRepository.fetchUserBy(userID: memberId)
                .sink { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.viewState = .initial
                        self?.showToastFor(error)
                    }
                } receiveValue: { user in
                    guard let user else { return }
                    users.append(user)
                    queue.leave()
                }.store(in: &cancelable)
        }

        queue.notify(queue: .main) {
            self.groupMembers = users
            self.viewState = .initial
        }
    }

    func handleMemberSelection() {
        splitAmount = totalAmount / Double(members.count)
    }

    func handleDoneAction(completion: @escaping () -> Void) {
        onMemberSelection(members)
    }
}

// MARK: - View States
extension ExpenseSplitOptionsViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
