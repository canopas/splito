//
//  GroupHomeViewModel.swift
//  Splito
//
//  Created by Amisha Italiya on 06/03/24.
//

import Data

class GroupHomeViewModel: BaseViewModel, ObservableObject {

    @Inject var groupRepository: GroupRepository
    @Inject var expenseRepository: ExpenseRepository

    @Published var expenses: [Expense] = []
    @Published var groupState: GroupState = .noMember
    @Published var groupExpenseState: GroupExpenseState = .noExpense

    var group: Groups?
    private let groupId: String
    private let router: Router<AppRoute>

    init(router: Router<AppRoute>, groupId: String) {
        self.router = router
        self.groupId = groupId

        super.init()

        fetchGroup()
        fetchExpenses()
    }

    func fetchGroup() {
        groupRepository.fetchGroupBy(id: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] group in
                guard let self, let group else { return }
                self.group = group
                self.groupState = group.members.count == 1 ? .noMember : .hasMembers
            }.store(in: &cancelable)
    }

    func fetchExpenses() {
        expenseRepository.fetchExpensesBy(groupId: groupId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.showToastFor(error)
                }
            } receiveValue: { [weak self] expenses in
                guard let self else { return }

                var combinedData: [ExpenseWithUser] = []
                let group = DispatchGroup() // dispatch group to wait for all asynchronous fetch operations

                for expense in expenses {
                    group.enter()

                    self.fetchUserData(for: expense.paidBy) { user in
                        let expenseWithUser = ExpenseWithUser(expense: expense, user: user)
                        combinedData.append(expenseWithUser)
                        group.leave() // Leave the dispatch group after each fetch operation
                    }
                }

                // Notify when all fetch operations are complete
                group.notify(queue: .main) {
                    self.groupExpenseState = expenses.isEmpty ? .noExpense : .hasExpense(expense: combinedData)
                }
            }.store(in: &cancelable)
    }

    func fetchUserData(for userId: String, completion: @escaping (AppUser) -> Void) {
        groupRepository.fetchMemberBy(userId: userId)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.showToastFor(error)
                }
            } receiveValue: { user in
                guard let user else { return }
                completion(user)
            }.store(in: &cancelable)
    }

    func handleCreateGroupClick() {
        router.push(.CreateGroupView(group: nil))
    }

    func handleAddMemberClick() {
        router.push(.InviteMemberView(groupId: groupId))
    }

    func handleSettingButtonTap() {
        router.push(.GroupSettingView(groupId: groupId))
    }
}

// MARK: - Group State
extension GroupHomeViewModel {
    enum GroupState {
        case noGroup
        case noMember
        case hasMembers
    }

    enum GroupExpenseState {
        case noExpense
        case hasExpense(expense: [ExpenseWithUser])
    }
}

// Struct to hold combined expense and user information
struct ExpenseWithUser: Hashable {
    let expense: Expense
    let user: AppUser
}
