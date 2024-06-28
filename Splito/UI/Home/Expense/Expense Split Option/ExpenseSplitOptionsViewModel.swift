//
//  ExpenseSplitOptionsViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 22/04/24.
//

import Data
import Combine
import BaseStyle

class ExpenseSplitOptionsViewModel: BaseViewModel, ObservableObject {

    @Inject private var preference: SplitoPreference
    @Inject private var userRepository: UserRepository
    @Inject private var expenseRepository: ExpenseRepository

    @Published private(set) var splitAmount: Double = 0
    @Published private(set) var totalPercentage: Double = 0
    @Published private(set) var totalShares: Double = 0

    @Published private(set) var groupMembers: [AppUser] = []
    @Published private(set) var percentages: [String: Double] = [:]

    @Published private(set) var viewState: ViewState = .initial
    @Published var selectedTab: SplitType = .equally

    @Published var selectedMembers: [String] {
        didSet {
            splitAmount = totalAmount / Double(selectedMembers.count)
        }
    }

    var isAllSelected: Bool {
        members.count == selectedMembers.count
    }

    private var members: [String] = []
    private var totalAmount: Double = 0
    private var onMemberSelection: (([String]) -> Void)

    init(amount: Double, members: [String], selectedMembers: [String], onMemberSelection: @escaping (([String]) -> Void)) {
        self.totalAmount = amount
        self.members = members
        self.selectedMembers = selectedMembers
        self.onMemberSelection = onMemberSelection
        super.init()

        fetchUsersData()
        splitAmount = totalAmount / Double(selectedMembers.count)
    }

    private func fetchUsersData() {
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

    func checkIsMemberSelected(_ memberId: String) -> Bool {
        return selectedMembers.contains(memberId)
    }

    func updatePercentage(for memberId: String, percentage: Double) {
        percentages[memberId] = percentage
        totalPercentage = percentages.values.reduce(0, +)
    }

    func handleAllBtnAction() {
        if isAllSelected {
            selectedMembers = [preference.user?.id ?? ""]
        } else {
            selectedMembers = members
        }
    }

    func handleMemberSelection(_ memberId: String) {
        if selectedMembers.contains(memberId) {
            if selectedMembers.count > 1 {
                selectedMembers.removeAll(where: { $0 == memberId })
            } else {
                showToastFor(toast: ToastPrompt(type: .warning, title: "Warning", message: "You must select at least one person to split with."))
            }
        } else {
            selectedMembers.append(memberId)
        }
    }

    func handleDoneAction(completion: @escaping () -> Void) {
        onMemberSelection(selectedMembers)
        completion()
    }
}

// MARK: - View States
extension ExpenseSplitOptionsViewModel {
    enum ViewState {
        case initial
        case loading
    }
}
